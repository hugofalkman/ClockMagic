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
    
    private let googleCalendar = GoogleCalendar()
    private let synthesizer = AVSpeechSynthesizer()
    private let dateFormatter = DateFormatter.shared
    
    private var eventsObserver: NSObjectProtocol?
    private var signedInObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?
    
    private weak var clockTimer: Timer?
    private weak var eventTimer: Timer?
    private var speakEventTimer: Timer?
    private var firstEvent: Event?
    private var speakTimeTimer: Timer?
    private var userName: String?
    
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
        // Configure Google Sign-in and the sign-in button
        GIDSignIn.sharedInstance().uiDelegate = self
        signInButton.style = GIDSignInButtonStyle.wide
        signInButton.colorScheme = GIDSignInButtonColorScheme.dark
        
        // Setup Start Message and initialize ClockView
        startMessage.text = NSLocalizedString("Logga in på ditt Google-konto", comment: "Initially displayed message")
        clockView = ClockView.init(frame: subView.bounds)
        
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
    }
    
    // MARK: - Google ID Signin
    
    private func googleSignedIn(userInfo: [AnyHashable: Any]?) {
        
        if let error = userInfo?["error"] as? Error {
            // Ignore errors before viewDidLoad complete
            if self.isViewLoaded && (self.view.window != nil) { showAlert(
                title: NSLocalizedString("Auktoriseringsfel",
                comment: "Wrong password or similar"),
                message: error.localizedDescription, okAction: nil)
            }
        } else {
            if let observer = signedInObserver {
                NotificationCenter.default.removeObserver(observer)
                signedInObserver = nil
            }
            startMessage.isHidden = true
            signInButton.isHidden = true
            userName = userInfo?["name"] as? String
            spinner.startAnimating()
            
            // Same process as when (later) returning to foregrund from background
            willEnterForeground()
        }
    }
    
    // MARK: - Application Life Cycle
    
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
        
        // Start clock
        if clockTimer == nil {
            clockTimer = Timer.scheduledTimer(timeInterval: TimingConstants.clockTimer, target: self, selector: #selector(updateClock), userInfo: nil, repeats: true)
        }
        
        // Initialize local Calendar and speak first time
        currentDate = Date()
        updateCalendar()
        speakTime(first: true)
        
        // Request events from GoogleCalendar and wait for request to complete
        eventsObserver = NotificationCenter.default.addObserver(
            forName: .EventsDidChange,
            object: googleCalendar,
            queue: OperationQueue.main,
            using: { (notification) in
                self.eventsDidChange(userInfo: notification.userInfo)
            }
        )
        googleCalendar.getEvents()
        
        // Refresh events regularly
        if eventTimer == nil {
            eventTimer = Timer.scheduledTimer(timeInterval: TimingConstants.eventTimer,
                target: googleCalendar, selector: #selector(googleCalendar.getEvents),
                userInfo: nil, repeats: true)
        }
    }
    
    private func eventsDidChange(userInfo: [AnyHashable: Any]?) {
        currentDate = googleCalendar.currentDate
        updateCalendar()
        
        // oldEvents is only empty the very first time
        if oldEvents.isEmpty {
            spinner.stopAnimating()
        }
        
        // Speaking time on the hour
        // Assuming event refresh rate is less than one hour does not need to repeat
        if speakTimeTimer == nil {
            startSpeakTimeTimer()
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
            
            // Check if speakEvent needs initiating
            checkSpeakEventTimer()
            
            tableView.setup(events: events, isRedBackground: false, currentDate: currentDate)
        }
    }
    
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
        
        // Remove observers and invalidate timers
        if let observer = eventsObserver {
            NotificationCenter.default.removeObserver(observer)
            eventsObserver = nil
        }
        if let observer = signedInObserver {
            NotificationCenter.default.removeObserver(observer)
            signedInObserver = nil
        }
        if clockTimer != nil {
            clockTimer?.invalidate()
        }
        if eventTimer != nil {
            eventTimer?.invalidate()
        }
        if tableView.photoTimer != nil {
            tableView.photoTimer?.invalidate()
        }
        if speakTimeTimer != nil {
            speakTimeTimer?.invalidate()
            speakTimeTimer = nil
        }
        if speakEventTimer != nil {
            speakEventTimer?.invalidate()
            speakEventTimer = nil
        }
    }
    
    // MARK: - Update clock and local calendar
    
    @objc private func updateClock() {
        if let clockView = clockView {
            clockView.setNeedsDisplay(clockView.clockFrame)
        }
    }
    
    @objc private func updateCalendar() {
        dateFormatter.formattingContext = .standalone
        dayOfWeekLabel.text = dateFormatter.weekdaySymbols[Calendar.autoupdatingCurrent.component(.weekday, from: currentDate) - 1]
        
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: currentDate)
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
        
        let monthday = Calendar.autoupdatingCurrent.dateComponents([.month, .day], from: currentDate)
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
        
        dateFormatter.setLocalizedDateFormatFromTemplate("MMMM d, YYYY")
        dateLabel.text = dateFormatter.string(from: currentDate)
    }
    
    // MARK: - Speech output
    
    private func startSpeakTimeTimer() {
        if let date = Calendar.autoupdatingCurrent.date(byAdding: .hour,
            value: TimingConstants.speakTimeHour, to: Date()) {
            let hour = Calendar.autoupdatingCurrent.component(.hour, from: date)
            if let firingDate = Calendar.autoupdatingCurrent.date(
                bySettingHour: hour, minute: 0, second: 1, of: date) {
                speakTimeTimer = Timer(fireAt: firingDate, interval: 0, target: self, selector: #selector(speakTime), userInfo: nil, repeats: false)
                RunLoop.main.add(speakTimeTimer!, forMode: .commonModes)
            }
        }
    }
    
    @objc private func speakTime(first: Bool = false) {
        speakTimeTimer = nil
        let hello = NSLocalizedString("Hej %@, klockan är %@.", comment: "Hello Name, it's Time")
        var time = ""
        var date = Date()
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: date)
        
        if "sv" == Locale.autoupdatingCurrent.languageCode {
            if first {
                let minute = Calendar.autoupdatingCurrent.component(.minute, from: date)
                time = DateComponentsFormatter.localizedString(from:
                    DateComponents(hour: hour, minute: minute), unitsStyle: .positional) ?? ""
            } else {
                time = DateComponentsFormatter.localizedString(from:
                    DateComponents(hour: (hour == 0) ? 24: hour), unitsStyle: .positional) ?? ""
            }
        } else {
            dateFormatter.dateStyle = .none
            dateFormatter.timeStyle = .short
            if !first {
                date = Calendar.autoupdatingCurrent.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
            }
            time = dateFormatter.string(from: date)
        }
        
        let speech = String.localizedStringWithFormat(hello, userName ?? "", time)
        let language = Locale.autoupdatingCurrent.identifier
        let utterance = AVSpeechUtterance(string: speech as String)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        synthesizer.speak(utterance)
    }
    
    private func checkSpeakEventTimer() {
        let newFirstEvent = findFirstEvent()
        guard newFirstEvent != firstEvent else { return }
        firstEvent = newFirstEvent
        if speakEventTimer != nil {
            speakEventTimer?.invalidate()
            speakEventTimer = nil
        }
        guard let event = newFirstEvent else { return }
        let date = event.start - TimingConstants.speakEventNoticeTime
        speakEventTimer = Timer(fireAt: date, interval: 0, target: self, selector: #selector(speakEvent), userInfo: nil, repeats: false)
        RunLoop.main.add(speakEventTimer!, forMode: .commonModes)
    }
    
    @objc private func speakEvent() {
        speakEventTimer = nil
    }
    
    private func findFirstEvent() -> Event? {
        let earliestEvent = events.filter { $0.hasTime }.first
        if let event = earliestEvent {
            let noticeTimeInterval = event.start.timeIntervalSinceNow - TimingConstants.speakEventNoticeTime
            if noticeTimeInterval > 1 && noticeTimeInterval < TimingConstants.speakEventTimerMax {
                return event
            } else { return nil }
        } else { return nil }
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
            if speakTimeTimer != nil {
                speakTimeTimer?.invalidate()
                speakTimeTimer = nil
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
    
    // MARK: - Displaying Alert helper function
    
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

// MARK: - Constants and global variables

extension DateFormatter {
    static let shared = DateFormatter()
}

struct TimingConstants {
    static let clockTimer = 0.25
    static let eventTimer = 5 * 60.0
    static let photoTimer = 8.0
    static let speakTimeHour = 1
    static let speakEventTimerMax = 60 * 60.0
    static let speakEventNoticeTime = 10 * 60.0
    static let googleTimeout = 30.0
    static let calendarEventMax = 4.5 * 24 * 3600.0
    static let cacheDisk = 200 * 1024 * 1024
}

