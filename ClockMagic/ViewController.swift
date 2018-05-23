//
//  ViewController.swift
//  ClockMagic
//
//  Created by H Hugo Falkman on 2018-04-30.
//  Copyright © 2018 H Hugo Falkman. All rights reserved.
//

import UIKit
import GoogleAPIClientForREST
import GoogleSignIn

// MARK: - TableView Cell

class ViewCell: UITableViewCell {
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        layoutIfNeeded()
    }
    
    @IBOutlet weak var creatorPhoto: UIImageView!
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
}

class ViewController: UIViewController, UITableViewDataSource,UITableViewDelegate, GIDSignInDelegate, GIDSignInUIDelegate {
    
    // MARK: - Properties
 
    @IBOutlet weak var startMessage: UITextView!
    
    @IBOutlet weak var subView: UIView!
    
    @IBOutlet weak var dayOfWeekLabel: UILabel!
    @IBOutlet weak var timeOfDayLabel: UILabel!
    @IBOutlet weak var seasonLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    @IBOutlet weak var tableView: UITableView!
    
    private var events = [Event]()
    private var oldEvents = [Event]()
    private var eventsByDay = [[Event]]()
    private var isRedBackground = false
    private var currentDate = Date()
    
    private var eventObserver: NSObjectProtocol?
    private let googleCalendar = GoogleCalendar()
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
    
    // Google GTLR framework
    // When scopes change, delete access token in Keychain by uninstalling the app
    private let scopes = [
        kGTLRAuthScopeCalendarReadonly,
        kGTLRAuthScopePeopleServiceContactsReadonly
    ]
    var signInButton = GIDSignInButton()
    
    // MARK: - View Controller Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure Google Sign-in.
        GIDSignIn.sharedInstance().delegate = self
        GIDSignIn.sharedInstance().uiDelegate = self
        GIDSignIn.sharedInstance().scopes = scopes
        GIDSignIn.sharedInstance().language = Locale.current.languageCode
        
        // Automatic Google Sign-in if access token saved in Keychain
        GIDSignIn.sharedInstance().signInSilently()
        
        // Configure GTLR services
        googleCalendar.service.isRetryEnabled = true
        googleCalendar.service.maxRetryInterval = 30
        googleCalendar.service2.isRetryEnabled = true
        googleCalendar.service2.maxRetryInterval = 30
        
        // Set up Start Message
        startMessage.text = NSLocalizedString("Logga in på ditt Google-konto", comment: "initially displayed message")
        
        // Add the sign-in button.
        signInButton.style = GIDSignInButtonStyle.wide
        signInButton.colorScheme = GIDSignInButtonColorScheme.dark
        tableView.addSubview(signInButton)
        signInButton.center = CGPoint(x: view.bounds.width / 4, y: view.bounds.height / 2)
        
        // Setup TableView
        tableView.delegate = self
        tableView.dataSource = self
        
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
    
    // MARK: - Google ID Signin Delegate
    
    // didSignIn
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!,
              withError error: Error!) {
        if let error = error {
            // Ignore error messages before viewDidLoad finishes
            if self.isViewLoaded && (self.view.window != nil) {
                showAlert(title: NSLocalizedString("Auktoriseringsfel", comment: "Fel password och liknande") , message: error.localizedDescription)
            }
            self.googleCalendar.service.authorizer = nil
            self.googleCalendar.service.authorizer = nil
        } else {
            self.startMessage.isHidden = true
            self.signInButton.isHidden = true
            let accessToken = user.authentication.fetcherAuthorizer()
            self.googleCalendar.service.authorizer = accessToken
            self.googleCalendar.service2.authorizer = accessToken
            
            eventObserver = NotificationCenter.default.addObserver(
                forName: .EventsDidChange,
                object: googleCalendar,
                queue: OperationQueue.main,
                using: { (notification) in
                    self.eventsDidChange()
                }
            )
            googleCalendar.getEvents()
            Timer.scheduledTimer(timeInterval: 120, target: googleCalendar, selector: #selector(googleCalendar.getEvents), userInfo: nil, repeats: true)
        }
    }
    
    private func eventsDidChange() {
        currentDate = googleCalendar.currentDate
        updateCalendar()
        let error = googleCalendar.eventsInError
        if error {
            displayError()
        } else {
            events = googleCalendar.events
            // save results for possible later display if the connection to Google goes down
            oldEvents = events
        }
        prepareForTableView(isRedBackground: error)
    }
    
    private func displayError() {
        events = oldEvents
        
        let start = currentDate
        let title = NSLocalizedString("Fel. Kunde inte läsa kalendern.", comment: "Error message")
        events.insert(Event(start: start, hasTime: true,
            title: getEventTitle(startDate: start, hasTime: true, title: title),
            detail: NSLocalizedString("Följande händelser kanske inte längre är aktuella.",
            comment: "Error detail"), creator: "", photo: nil), at: 0)
    }
    
    private func getEventTitle(startDate start: Date, hasTime notAllDay: Bool, title: String) -> String {
        
//        dateFormatter.dateStyle = .medium
//        dateFormatter.timeStyle = .none
//        var startDate = dateFormatter.string(from: start)
//        startDate = String(startDate.dropLast(5)) // drop year
        
        guard notAllDay else { return title }
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short
        let startTime = dateFormatter.string(from: start)
        return startTime + " - " + title
        //return startDate + " " + startTime + " - " + title
    }
    
    // MARK: - Prepare for TableView
    
    private func prepareForTableView(isRedBackground isRed: Bool) {
        isRedBackground = isRed
        eventsByDay = []
        let calendar = Calendar.current
        eventsByDay.append(events.filter {calendar.isDateInToday($0.start) })
        eventsByDay.append(events.filter {calendar.isDateInTomorrow($0.start) })
        eventsByDay.append(events.filter {!calendar.isDateInToday($0.start) && !calendar.isDateInTomorrow($0.start) })
        
        tableView.reloadData()
    }
    
    // MARK: - TableView Data Source/Delegate
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        guard !eventsByDay.isEmpty else { return nil }
        guard !eventsByDay[section].isEmpty else { return nil }
        
        let header = UILabel()
        header.font = UIFont.systemFont(ofSize: 25, weight: .medium)
        header.sizeToFit()
        
        var day = currentDate
        switch section {
        case 0:
            header.text = NSLocalizedString("I dag", comment: "header")
        case 1:
            header.text = NSLocalizedString("I morgon", comment: "header")
            day = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        case 2:
            header.text = NSLocalizedString("I övermorgon", comment: "header")
            day = Calendar.current.date(byAdding: .day, value: 2, to: day)!
            
        default:
            header.text = "error"
        }

        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        var formattedDay = dateFormatter.string(from: day)
        formattedDay = String(formattedDay.dropLast(5)) // drop year
        header.text = (header.text! + " " + formattedDay).uppercased()
        return header
    }
    
    // This returns 0 until (some) data has been retrieved from web. The 0 signals to TableView not to continue. Once all photos have been retrieved on background thread, tableView.reloadData is invoked on the main thread finishing populating the tableView
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        guard !eventsByDay.isEmpty else { return 0 }
        return eventsByDay[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! ViewCell
        
        let row = indexPath.row
        let section = indexPath.section
        
        if section == 0 && row == 0 && isRedBackground == true {
            cell.backgroundColor = Color.red
        } else if !eventsByDay[section][row].hasTime {
            cell.backgroundColor = Color.yellowBackground
        } else {
            cell.backgroundColor = nil
        }
        
        cell.headerLabel.text = eventsByDay[section][row].title
        cell.descriptionLabel.text = eventsByDay[section][row].detail
        cell.creatorPhoto.image = eventsByDay[section][row].photo
        cell.layoutIfNeeded()
        return cell
    }
    
    // MARK: - Showing Alert helper function
    
    private func showAlert(title : String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: UIAlertControllerStyle.alert
        )
        let ok = UIAlertAction(
            title: "OK",
            style: UIAlertActionStyle.default,
            handler: nil
        )
        alert.addAction(ok)
        self.present(alert, animated: true, completion: nil)
    }
}
