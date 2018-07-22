//
//  ViewController.swift
//  ClockMagic
//
//  Created by H Hugo Falkman on 2018-04-30.
//  Copyright © 2018 H Hugo Falkman. All rights reserved.
//

import UIKit
import GoogleSignIn

extension DateFormatter {
    static let shared = DateFormatter()
}

class ViewController: UIViewController, GIDSignInUIDelegate {
    
    // MARK: - Properties
    
    @IBOutlet private weak var clockView: ClockView!
    @IBOutlet private weak var localCalendarView: LocalCalendarView!
    @IBOutlet private weak var tableView: MyUITableView!
    @IBOutlet private weak var spinner: UIActivityIndicatorView!
    @IBOutlet private weak var loginView: UIView!
    
    private var events = [Event]()
    private var oldEvents = [Event]()
    private var currentDate = Date()
    
    private var embeddedGoogleLogin: GoogleLoginViewController?
    private var googleCalendar = GoogleCalendar()
    private let speaker = Speaker()
    private let dateFormatter = DateFormatter.shared
    
    private var eventsObserver: NSObjectProtocol?
    private var signedInObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?
    
    private weak var eventTimer: Timer?
    
    // MARK: - View Controller Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        registerSettingsBundle()
        updateConstantsFromDefaults()
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: UserDefaults.standard, queue: .main)
            { notification in self.updateConstantsFromDefaults() }
        
        loginView.alpha = 1
        
        // Same process as when (later) returning to foreground from background
        willEnterForeground()
    }
    
    //MARK: - Settings bundle and UserDefault
    
    private func registerSettingsBundle() {
        let appDefaults: [String: Any] = ["saveAuthorization": true,
            "calendarEventMax": 3.0, "eventTimer": 15.0, "googleTimeout": 30.0,
            "speechEnabled": true, "speakEventNoticeTime": 10.0, "photoTimer": 8.0]
        UserDefaults.standard.register(defaults: appDefaults)
    }
    
    private func updateConstantsFromDefaults() {
        let defaults = UserDefaults.standard
        TimingConstants.saveAuthorization = defaults.bool(forKey: "saveAuthorization")
        TimingConstants.calendarEventMax = defaults.double(forKey: "calendarEventMax") * 24 * 3600.0
        TimingConstants.eventTimer = defaults.double(forKey: "eventTimer") * 60.0
        TimingConstants.googleTimeout = defaults.double(forKey: "googleTimeout")
        TimingConstants.speechEnabled = defaults.bool(forKey: "speechEnabled")
        TimingConstants.speakEventNoticeTime = defaults.double(forKey: "speakEventNoticeTime") * 60.0
        TimingConstants.photoTimer = defaults.double(forKey: "photoTimer")
    }
    
    // MARK: - Application Life Cycle, entering foreground
    
    private func willEnterForeground() {
        // Switch background/foreground observer
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
            foregroundObserver = nil
        }
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: .UIApplicationDidEnterBackground,
            object: UIApplication.shared, queue: OperationQueue.main)
            { notification in self.didEnterBackgrund() }
        
        // Start clock, initialize local Calendar and speak first time
        clockView.startClock()
        localCalendarView.update(currentDate: Date())
        speaker.speakTimeFirst()
        
        // Speaking time on the hour
        if speaker.speakTimeTimer == nil {
            speaker.startSpeakTimeTimer()
        }
        
        // Start Google GID Signin and wait for it to complete
        signedInObserver = NotificationCenter.default.addObserver(
            forName: .GoogleSignedIn, object: googleCalendar, queue: .main)
            { notification in self.googleSignedIn(userInfo: notification.userInfo) }
        googleCalendar.setupGIDSignIn()
    }
    
    // MARK: - Google signed in
    
    private func googleSignedIn(userInfo: [AnyHashable: Any]?) {
        if let error = userInfo?["error"] as? Error {
            // Ignore errors before viewDidLoad complete
            if self.isViewLoaded && (self.view.window != nil) { showAlert(
                title: NSLocalizedString("Auktoriseringsfel", comment: "Wrong password or similar"),
                message: error.localizedDescription, okAction: nil)
            }
        } else {
            if let observer = signedInObserver {
                NotificationCenter.default.removeObserver(observer)
                signedInObserver = nil
            }
            
            UIView.transition(with: loginView, duration: 0.5, options: [.transitionCrossDissolve,
                .curveEaseInOut], animations: { self.loginView.isHidden = true })
            
            speaker.userName = userInfo?["name"] as? String
            events = []
            oldEvents = []
            currentDate = Date()
            tableView.isHidden = true
            spinner.startAnimating()
            
            // Request events from GoogleCalendar and wait for request to complete
            eventsObserver = NotificationCenter.default.addObserver(
                forName: .EventsDidChange, object: googleCalendar, queue: OperationQueue.main)
                { notification in self.eventsDidChange(userInfo: notification.userInfo) }
            googleCalendar.getEvents()
            
            // Refresh events regularly
            if eventTimer == nil {
                eventTimer = Timer.scheduledTimer(timeInterval: TimingConstants.eventTimer,
                    target: googleCalendar, selector: #selector(googleCalendar.getEvents),
                    userInfo: nil, repeats: true)
            }
        }
    }
    
    // MARK: - Events refreshed by model
    
    private func eventsDidChange(userInfo: [AnyHashable: Any]?) {
        currentDate = googleCalendar.currentDate
        localCalendarView.update(currentDate: currentDate)
        
        // oldEvents is only empty the very first time
        if oldEvents.isEmpty {
            tableView.isHidden = false
            spinner.stopAnimating()
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
            
            speaker.checkSpeakEventTimer(events: events)
            tableView.setup(events: events, isRedBackground: false, currentDate: currentDate)
        }
    }
    
    // MARK: - Aoplication Life Cycle, entered background
    
    private func didEnterBackgrund() {
        // Switch background/foreground observer
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
            backgroundObserver = nil
        }
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: .UIApplicationWillEnterForeground,
            object: UIApplication.shared, queue: OperationQueue.main)
            { notification in self.willEnterForeground() }
        
        // Invalidate timers
        if clockView.clockTimer != nil {
            clockView.clockTimer?.invalidate()
        }
        if eventTimer != nil {
            eventTimer?.invalidate()
        }
        if tableView.photoTimer != nil {
            tableView.photoTimer?.invalidate()
        }
        if speaker.speakTimeTimer != nil {
            speaker.speakTimeTimer?.invalidate()
            speaker.speakTimeTimer = nil
        }
        if speaker.speakEventTimer != nil {
            speaker.speakEventTimer?.invalidate()
            speaker.speakEventTimer = nil
        }
        
        // Remove observers
        if let observer = eventsObserver {
            NotificationCenter.default.removeObserver(observer)
            eventsObserver = nil
        }
        if let observer = signedInObserver {
            NotificationCenter.default.removeObserver(observer)
            signedInObserver = nil
        }
        
        loginView.isHidden = false
        tableView.isHidden = true
        
        // Get a new instance of the model
        googleCalendar = GoogleCalendar()
    }
    
    // MARK: - Displaying errors
    
    private func displayError(error: NSError?) {
        if let error = error {
            print("\(error.code) " + error.localizedDescription)
        } else { print("nil error") }
        
        if oldEvents.isEmpty {
            // very first getEvents request resulted in error
            if eventTimer != nil {
                eventTimer?.invalidate()
            }
            if speaker.speakTimeTimer != nil {
                speaker.speakTimeTimer?.invalidate()
                speaker.speakTimeTimer = nil
            }
            let message = NSLocalizedString(
                "Fel. Kunde inte läsa kalendern.", comment: "Error message")
            showAlert(title: NSLocalizedString("Åtkomstfel",comment: "Error message"),
                message: message)
                { action in self.googleSignout() } // Signout and start again
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
    
    private func googleSignout() {
        GIDSignIn.sharedInstance().signOut()
        signedInObserver = NotificationCenter.default.addObserver(
            forName: .GoogleSignedIn, object: self.googleCalendar, queue: OperationQueue.main)
            { notification in self.googleSignedIn(userInfo: notification.userInfo) }
        UIView.transition(with: loginView, duration: 0.5, options: [.transitionCrossDissolve,
            .curveEaseInOut], animations: { self.loginView.isHidden = false })
    }
    
    // MARK: - Displaying Alert helper function
    
    private func showAlert(title : String, message: String,
        okAction: ((UIAlertAction) -> Void)?) {
        if presentedViewController == nil {
            let alert = UIAlertController(
                title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
            let ok = UIAlertAction(
                title: "OK", style: UIAlertActionStyle.default, handler: okAction)
            alert.addAction(ok)
            present(alert, animated: true, completion: nil)
        }
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "GoogleLogin" {
            embeddedGoogleLogin = segue.destination.contents as? GoogleLoginViewController
        }
    }
}

