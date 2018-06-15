//
//  ViewController.swift
//  ClockMagic
//
//  Created by H Hugo Falkman on 2018-04-30.
//  Copyright © 2018 H Hugo Falkman. All rights reserved.
//

import UIKit
import GoogleSignIn

class ViewController: UIViewController, GIDSignInUIDelegate {
    
    // MARK: - Properties
    
    @IBOutlet private weak var dayOfWeekLabel: UILabel!
    @IBOutlet private weak var timeOfDayLabel: UILabel!
    @IBOutlet private weak var seasonLabel: UILabel!
    @IBOutlet private weak var dateLabel: UILabel!
    
    @IBOutlet private weak var subView: UIView!
    @IBOutlet private weak var tableView: MyUITableView!
    @IBOutlet private weak var spinner: UIActivityIndicatorView!
    
    @IBOutlet private weak var startMessage: UITextView!
    @IBOutlet private weak var signInButton: GIDSignInButton!
    
    private var events = [Event]()
    private var oldEvents = [Event]()
    
    private var currentDate = Date()
    
    private var eventsObserver: NSObjectProtocol?
    private var signedInObserver: NSObjectProtocol?
    
    private let googleCalendar = GoogleCalendar()
    
    private weak var eventTimer: Timer?
    
    private let dateFormatter = DateFormatter()
    
    private var clockView: ClockView? {
        willSet {
            let clockView = self.clockView
            clockView?.removeFromSuperview()
        }
        didSet {
            if let clockView = clockView {
                clockView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                subView.addSubview(clockView)
            }
        }
    }
    
    // MARK: - View Controller Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure Google Sign-in.
        GIDSignIn.sharedInstance().uiDelegate = self
        
        // Set up Start Message
        startMessage.text = NSLocalizedString("Logga in på ditt Google-konto", comment: "Initially displayed message")
        
        // Configure the sign-in button.
        signInButton.style = GIDSignInButtonStyle.wide
        signInButton.colorScheme = GIDSignInButtonColorScheme.dark
        
        // Start Google GID Signin and wait for it to complete
        signedInObserver = NotificationCenter.default.addObserver(
            forName: .GoogleSignedIn,
            object: googleCalendar,
            queue: OperationQueue.main,
            using: { (notification) in
                self.googleSignedIn(userInfo: notification.userInfo)
            }
        )
        googleCalendar.setupGIDSignIn()
        
        // Setup ClockView and start clock
        clockView = ClockView.init(frame: subView.bounds)
        Timer.scheduledTimer(timeInterval: 0.25, target: self, selector: #selector(updateClock), userInfo: nil, repeats: true)
        
        // Initialize local Calendar
        updateCalendar()
    }
    
    @objc private func updateClock() {
        if let clockView = clockView {
            clockView.setNeedsDisplay(clockView.clockFrame)
        }
    }
    
    @objc private func updateCalendar() {
        dayOfWeekLabel.text = dateFormatter.weekdaySymbols[Calendar.current.component(.weekday, from: currentDate) - 1]
        
        let hour = Calendar.current.component(.hour, from: currentDate)
        switch hour {
        case 22...23, 0...5:
            timeOfDayLabel.text = NSLocalizedString("natt", comment: "time of day")
        case 6...8:
            timeOfDayLabel.text = NSLocalizedString("morgon", comment: "time of day")
        case 9...11:
            timeOfDayLabel.text = NSLocalizedString("förmiddag", comment: "time of day")
        case 12...17:
            timeOfDayLabel.text = NSLocalizedString("eftermiddag", comment: "time of day")
        case 18...21:
            timeOfDayLabel.text = NSLocalizedString("kväll", comment: "time of day")
        default:
            timeOfDayLabel.text = nil
        }
        
        let monthday = Calendar.current.dateComponents([.month, .day], from: currentDate)
        switch (monthday.month ?? 0, monthday.day ?? 0) {
        case (1...4, _), (12, _):
            seasonLabel.text = NSLocalizedString("vinter", comment: "season")
        case (5, _), (6, 1...15):
            seasonLabel.text = NSLocalizedString("vår", comment: "season")
        case (6, 16...30), (7...8, _):
            seasonLabel.text = NSLocalizedString("sommar", comment: "season")
        case (9...11, _):
            seasonLabel.text = NSLocalizedString("höst", comment: "season")
        default:
            seasonLabel.text = nil
        }
        
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        dateLabel.text = dateFormatter.string(from: currentDate)
    }
    
    // MARK: - Google ID Signin
    
    private func googleSignedIn(userInfo: [AnyHashable: Any]?) {
        
        if let error = userInfo?["error"] as? Error {
            // Ignore errors before viewDidLoad complete
            if self.isViewLoaded && (self.view.window != nil) {
                showAlert(title: NSLocalizedString("Auktoriseringsfel",
                    comment: "Wrong password or similar"),
                    message: error.localizedDescription,
                    okAction: nil)
            }
        } else {
            if let observer = signedInObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            self.startMessage.isHidden = true
            self.signInButton.isHidden = true
            
            // Request events from GoogleCalendar and wait for request to complete
            eventsObserver = NotificationCenter.default.addObserver(
                forName: .EventsDidChange,
                object: googleCalendar,
                queue: OperationQueue.main,
                using: { (notification) in
                    self.eventsDidChange(userInfo: notification.userInfo)
                }
            )
            spinner.startAnimating()
            googleCalendar.getEvents()
            
            // Refresh events regularly
            if eventTimer == nil {
                eventTimer = Timer.scheduledTimer(
                    timeInterval: 300, target: googleCalendar,
                    selector: #selector(googleCalendar.getEvents),
                    userInfo: nil, repeats: true)
            }
        }
    }
    
    private func eventsDidChange(userInfo: [AnyHashable: Any]?) {
        currentDate = googleCalendar.currentDate
        updateCalendar()
        
        // oldEvents only empty first time
        if oldEvents.isEmpty {
            spinner.stopAnimating()
        }
        
        let error = googleCalendar.eventsInError
        if error {
            displayError(error: userInfo?["error"] as? NSError)
        } else {
            // sort events on time
            events = googleCalendar.events.sorted {
                if $0.hasTime == $1.hasTime {
                    return $0.start < $1.start
                }
                return !$0.hasTime && $1.hasTime }
            
            // save results for possible later display if the connection to Google goes down
            oldEvents = events
            
            tableView.setup(events: events, isRedBackground: false, currentDate: currentDate)
        }
    }
    
    private func displayError(error: NSError?) {
        if let error = error {
            print("\(error.code) " + error.localizedDescription)
        } else { print("nil error") }
        
        if oldEvents.isEmpty {
            // very first getEvents request resulted in error
            if eventTimer != nil {
                eventTimer?.invalidate()
                eventTimer = nil
            }
            
            let message = NSLocalizedString(
                "Fel. Kunde inte läsa kalendern.", comment: "Error message")
            showAlert(title: NSLocalizedString("Åtkomstfel",comment: "Error message"),
                message: message) { action in
                // Signout and start again
                GIDSignIn.sharedInstance().signOut()
                self.signedInObserver = NotificationCenter.default.addObserver(
                    forName: .GoogleSignedIn,
                    object: self.googleCalendar,
                    queue: OperationQueue.main,
                    using: { (notification) in
                        self.googleSignedIn(userInfo: notification.userInfo)
                    }
                )
                self.signInButton.isHidden = false
            }
        } else {
            // If not first time continue displaying old events but with a warning at the beginning
            events = oldEvents
            let start = currentDate
            let summary = NSLocalizedString("Fel. Kunde inte läsa kalendern.", comment: "Error message")
            let detail = NSLocalizedString("Följande händelser kanske inte längre är aktuella.",
                comment: "Error detail")
            events.insert(Event(start: start, hasTime: true, summary: summary,
                detail: detail, creator: ""), at: 0)
            tableView.setup(events: events, isRedBackground: true, currentDate: currentDate)
        }
    }
    
    // MARK: - Showing Alert helper function
    
    private func showAlert(title : String, message: String,
        okAction: ((UIAlertAction) -> Void)?) {
        if presentedViewController == nil {
            let alert = UIAlertController(
                title: title,
                message: message,
                preferredStyle: UIAlertControllerStyle.alert
            )
            let ok = UIAlertAction(
                title: "OK",
                style: UIAlertActionStyle.default,
                handler: okAction
            )
            alert.addAction(ok)
            self.present(alert, animated: true, completion: nil)
        }
    }
}
