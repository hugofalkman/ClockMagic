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
    
    // MARK: - Properties and structs
    
    @IBOutlet weak var subView: UIView!
    
    @IBOutlet weak var dayOfWeekLabel: UILabel!
    @IBOutlet weak var timeOfDayLabel: UILabel!
    @IBOutlet weak var seasonLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    @IBOutlet weak var tableView: UITableView!
    
    private struct event {
        var start: Date
        var hasTime: Bool
        var title: String
        var detail: String
        var creator: String
        var photo: UIImage?
    }
    private var events = [event]()
    private var oldEvents = [event]()
    private var eventsByDay = [[event]]()
    
    private struct contact {
        var email: String
        var name: String
        var photoUrl: String
    }
    private var contacts = [contact]()
    
    private var isRedBackground = false
    
    private var currentDate = Date()
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
    
    // When these scopes change, delete saved credentials by uninstalling the app
    private let scopes = [kGTLRAuthScopeCalendarReadonly, kGTLRAuthScopePeopleServiceContactsReadonly]
    private let service = GTLRCalendarService()
    private let service2 = GTLRPeopleServiceService()
    var signInButton = GIDSignInButton()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure Google Sign-in.
        GIDSignIn.sharedInstance().delegate = self
        GIDSignIn.sharedInstance().uiDelegate = self
        GIDSignIn.sharedInstance().scopes = scopes
        GIDSignIn.sharedInstance().signInSilently()
        GIDSignIn.sharedInstance().language = Locale.current.languageCode
        
        // Configure GTLR services
        service.isRetryEnabled = true
        service.maxRetryInterval = 30
        service2.isRetryEnabled = true
        service2.maxRetryInterval = 30
        
        // Add the sign-in button.
        signInButton.style = GIDSignInButtonStyle.wide
        tableView.addSubview(signInButton)
        signInButton.center = CGPoint(x: view.bounds.width / 4, y: view.bounds.height / 2)
        
        // Setup TableView
        tableView.delegate = self
        tableView.dataSource = self
        // tableView.rowHeight = UITableViewAutomaticDimension
        tableView.sectionHeaderHeight = UITableViewAutomaticDimension
        // tableView.estimatedRowHeight = 150
        if #available(iOS 11.0, *) {
            tableView?.estimatedSectionHeaderHeight = 30
        }
        
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
    
    // Called when sign-in button pushed
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!,
              withError error: Error!) {
        if let error = error {
            showAlert(title: NSLocalizedString("Auktoriseringsfel", comment: "Fel password och liknande") , message: error.localizedDescription)
            self.service.authorizer = nil
        } else {
            self.signInButton.isHidden = true
            self.service.authorizer = user.authentication.fetcherAuthorizer()
            self.service2.authorizer = self.service.authorizer
            fetchContacts()
            Timer.scheduledTimer(timeInterval: 120, target: self, selector: #selector(fetchContacts), userInfo: nil, repeats: true)
        }
    }
    
    // MARK: - Get Google Contacts
    
    @objc private func fetchContacts() {
        let query = GTLRPeopleServiceQuery_PeopleConnectionsList.query(withResourceName: "people/me")
        query.personFields = "names,emailAddresses,photos"
        
        //  Get contacts in background
        DispatchQueue.global().async { [unowned self] in
            self.service2.executeQuery(
                query,
                delegate: self,
                didFinish: #selector(self.getContactsFromTicket(ticket:finishedWithObject:error:)))
        }
    }
    
    @objc func getContactsFromTicket(
        ticket: GTLRServiceTicket,
        finishedWithObject response: GTLRPeopleService_ListConnectionsResponse,
        error: NSError?) {
        
        contacts = []
        
        if error != nil {
            // Continue to fetch calendar items and display them without photos of the creator
            fetchEvents()
            return
        }
        
        if let connections = response.connections, !connections.isEmpty {
            loop: for connection in connections {
                var email = ""
                if let emailAddresses = connection.emailAddresses, !emailAddresses.isEmpty {
                    for address in emailAddresses {
                        if let _ = address.metadata?.primary {
                            email = address.value ?? ""
                        }
                    }
                }
                if email == "" { continue loop }
                
                var displayName = ""
                if let names = connection.names, !names.isEmpty {
                    for name in names {
                        if let _ = name.metadata?.primary {
                            displayName = name.displayName ?? ""
                        }
                    }
                }
                
                var url = ""
                if let photos = connection.photos, !photos.isEmpty {
                    for photo in photos {
                        if let _ = photo.metadata?.primary {
                            url = photo.url ?? ""
                        }
                    }
                }
                
                contacts.append(contact(email: email, name: displayName, photoUrl: url))
            }
        }
        fetchEvents()
    }
    
    // MARK: - Get Google Calendar Events
    
    // Construct a query and get a list of upcoming events from the user calendar
    private func fetchEvents() {
        
        //        let tQuery = GTLRCalendarQuery_CalendarListList.query()
        //        service.executeQuery(tQuery) { (ticket, response, error) in
        //            let list = response as! GTLRCalendar_CalendarList
        //            print(String(describing: list.items))
        //        }
        
        // Reset currentDate and update local calendar
        currentDate = Date()
        updateCalendar()
        
        let query = GTLRCalendarQuery_EventsList.query(withCalendarId: "primary")
        let startDate = currentDate
        query.timeMin = GTLRDateTime(date: startDate)
        // 48 hours of calendar data
        query.timeMax = GTLRDateTime(date: Date(timeInterval: 2 * 86400, since: startDate))
        query.singleEvents = true
        query.orderBy = kGTLRCalendarOrderByStartTime
        
        // Get calendar events in background
        DispatchQueue.global().async { [unowned self] in
            self.service.executeQuery(
                query,
                delegate: self,
                didFinish: #selector(self.getEventsFromTicket(ticket:finishedWithObject:error:)))
        }
    }
    
    // MARK: - Build events array
    
    @objc func getEventsFromTicket(
        ticket: GTLRServiceTicket,
        finishedWithObject response : GTLRCalendar_Events,
        error : NSError?) {
        
        if let error = error {
            // Display error and old events
            displayError(error: error.localizedDescription)
            return
        }
        
        if let items = response.items, !items.isEmpty {
            events = []
            
            for item in items {
                // If hasTime is false, start.date is set to noon GMT so day is correct in all timezones
                let start = item.start!.dateTime ?? item.start!.date!
                let title = item.summary ?? ""
                let hasTime = start.hasTime
                let creator = hasTime ? (item.creator?.email ?? "") : ""
                events.append(event(start: start.date, hasTime: hasTime, title: getEventTitle(startDate: start.date, hasTime: hasTime, title: title),
                    detail: item.descriptionProperty ?? "",
                    creator: creator,
                    photo: nil))
            }
        } else {
            let start = currentDate
            let title = NSLocalizedString("Inga kommande händelser", comment: "Message empty calendar")
            events = [event(start: start, hasTime: true, title: getEventTitle(startDate: start, hasTime: true, title: title),
                detail: "", creator: "", photo: nil)]
        }
        
        //  Get photos in background and when finished reload tableview from main queue
        DispatchQueue.global().async { [unowned self] in
            self.getCreatorPhotos()
            DispatchQueue.main.async {
                // save results for possible later display if the connection to Google goes down
                self.oldEvents = self.events
                self.prepareForTableView(isRedBackground: false)
            }
        }
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
    
    private func displayError(error: String) {
        events = oldEvents
        
        let start = currentDate
        let title = NSLocalizedString("Fel. Kunde inte läsa kalendern.", comment: "Error message")
        events.insert(event(start: start, hasTime: true, title: getEventTitle(startDate: start, hasTime: true, title: title),
            detail: NSLocalizedString("Följande händelser kanske inte längre är aktuella.", comment: "Error detail"),
            creator: "", photo: nil), at: 0)
        
        prepareForTableView(isRedBackground: true)
    }
    
    // MARK: Get creator photos from Google contacts list
    
    private func getCreatorPhotos() {
        guard !contacts.isEmpty else { return }
        guard !events.isEmpty else { return }
        let contactsEmail = contacts.map { $0.email }
        for eventIndex in 0..<events.count {
            if let index = contactsEmail.index(of: events[eventIndex].creator),
                events[eventIndex].creator != "" {
                    let urlString = contacts[index].photoUrl
                    if let url = URL(string: urlString),
                        // also discards the case urlString == ""
                        let data = try? Data(contentsOf: url) { // stacked if lets
                            events[eventIndex].photo = UIImage(data: data)
                    } else {
                        events[eventIndex].photo = nil
                    }
            } else {
                events[eventIndex].photo = nil
            }
        }
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
    
    // MARK: - TableView Data Source
    
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
        present(alert, animated: true, completion: nil)
    }
}
