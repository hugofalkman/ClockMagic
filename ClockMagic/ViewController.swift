//
//  ViewController.swift
//  ClockMagic
//
//  Created by H Hugo Falkman on 2018-04-30.
//  Copyright © 2018 H Hugo Falkman. All rights reserved.
//

import UIKit
import GoogleSignIn
import AVFoundation

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
    
    private weak var clockTimer: Timer?
    private weak var eventTimer: Timer?
    private var speechTimer: Timer?
    private var userName: String?
    
    private let dateFormatter = DateFormatter()
    private let synthesizer = AVSpeechSynthesizer()
    
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
        clockTimer = Timer.scheduledTimer(timeInterval: TimingConstants.clockTimer, target: self, selector: #selector(updateClock), userInfo: nil, repeats: true)
        
        // Initialize local Calendar
        updateCalendar()
        
        // Prepare to enter background
        NotificationCenter.default.addObserver(forName: .UIApplicationDidEnterBackground,
            object: UIApplication.shared, queue: OperationQueue.main) { notification in self.didEnterBackgrund()
        }
        NotificationCenter.default.addObserver(forName: .UIApplicationWillEnterForeground,
            object: UIApplication.shared, queue: OperationQueue.main) { notification in self.willEnterForeground()
        }
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
            startMessage.isHidden = true
            signInButton.isHidden = true
            
            userName = userInfo?["name"] as? String
            // Speaking time a first time
            speakTime()
            
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
                    timeInterval: TimingConstants.eventTimer, target: googleCalendar,
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
        
        // Speaking time on the hour
        // assuming event refresh rate is less than one hour does not need to repeat
        if speechTimer == nil {
            startSpeechTimer()
        }
        
        let error = googleCalendar.eventsInError
        if error {
            displayError(error: userInfo?["error"] as? NSError)
        } else {
            // Sort events on time, all day events first
            events = googleCalendar.events.sorted {
                if $0.hasTime == $1.hasTime {
                    return $0.start < $1.start
                }
                return !$0.hasTime && $1.hasTime }
            
            // Save results for possible later display if the connection to Google goes down
            oldEvents = events
            
            tableView.setup(events: events, isRedBackground: false, currentDate: currentDate)
        }
    }
    
    private func startSpeechTimer() {
        let date = Date()
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let firingDate = Calendar.current.date(bySettingHour:
            (comps.hour ?? 0) + TimingConstants.speakTimeHour,
                                               minute: 0, second: 1, of: date)
        if let firing = firingDate {
            speechTimer = Timer(fireAt: firing, interval: 0, target: self, selector: #selector(speakTime), userInfo: nil, repeats: false)
            RunLoop.main.add(speechTimer!, forMode: RunLoopMode.commonModes)
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
            if speechTimer != nil {
                speechTimer?.invalidate()
                speechTimer = nil
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
    
    // MARK: - Speech output
    
    @objc private func speakTime() {
        speechTimer = nil
        let hello = NSLocalizedString("Hej %@, klockan är %@.", comment: "Hello Name, it's Time")
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short
        let time = dateFormatter.string(from: Date())
        
        let speech = String.localizedStringWithFormat(hello, userName ?? "", time)
        let language = Locale.current.identifier
        let utterance = AVSpeechUtterance(string: speech as String)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        synthesizer.speak(utterance)
    }
    
    // MARK: - Application Life Cycle - methods triggered by ViewDidLoad Notifications
    
    private func didEnterBackgrund() {
        // print("Entering Background")
        if clockTimer != nil {
            clockTimer?.invalidate()
        }
        if eventTimer != nil {
            eventTimer?.invalidate()
        }
        if speechTimer != nil {
            speechTimer?.invalidate()
            speechTimer = nil
        }
    }
    
    private func willEnterForeground() {
        // print("Entering Foreground")
        if clockTimer == nil {
            clockTimer = Timer.scheduledTimer(timeInterval: TimingConstants.clockTimer,
            target: self, selector: #selector(updateClock), userInfo: nil, repeats: true)
        }
        if eventTimer == nil {
            eventTimer = Timer.scheduledTimer(timeInterval: TimingConstants.eventTimer,
            target: googleCalendar, selector: #selector(googleCalendar.getEvents),
            userInfo: nil, repeats: true)
        }
        speakTime()
        if speechTimer == nil {
            startSpeechTimer()
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

// MARK: - Constants

struct TimingConstants {
    static let clockTimer = 0.25
    static let eventTimer = 5 * 60.0
    static let speakTimeHour = 1
    static let googleTimeout = 30.0
    static let calendarEventMax = 2 * 24 * 3600.0
    static let cacheDisk = 200 * 1024 * 1024
}





