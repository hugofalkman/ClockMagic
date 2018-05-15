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
    
    @IBOutlet weak var subView: UIView!
    
    @IBOutlet weak var dayOfWeek: UILabel!
    @IBOutlet weak var timeOfDay: UILabel!
    @IBOutlet weak var season: UILabel!
    @IBOutlet weak var date: UILabel!
    
    @IBOutlet weak var tableView: UITableView!
    
    private var eventTitle: [String] = []
    private var eventDetail: [String] = []
    private var eventCreator: [String] = []
    private var eventPhoto: [UIImage?] = []
    
    private var oldEventTitle: [String] = []
    private var oldEventDetail: [String] = []
    private var oldEventPhoto: [UIImage?] = []
    
    private var contactEmail: [String] = []
    private var contactName: [String] = []
    private var contactPhoto: [String] = [] // A url not an image
    
    private var isRedBackground = false
    
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
    
    // If these scopes chamge, delete saved credentials by uninstalling the app
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
        signInButton.center = CGPoint(x: tableView.bounds.width / 2, y: tableView.bounds.height / 2)
        
        // Setup TableView
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 150
        
        // Setup ClockView and start clock
        clockView = ClockView.init(frame: subView.bounds)
        Timer.scheduledTimer(timeInterval: 0.25, target: self, selector: #selector(updateClock), userInfo: nil, repeats: true)
        
        // Setup and start local Calendar
        updateCalendar()
        Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(updateCalendar), userInfo: nil, repeats: true)
    }
    
    @objc private func updateClock() {
        if let clockView = clockView {
            clockView.setNeedsDisplay(clockView.clockFrame)
        }
    }
    
    @objc private func updateCalendar() {
        dayOfWeek.text = dateFormatter.weekdaySymbols[Calendar.current.component(.weekday, from: Date()) - 1]
        
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 22...23, 0...5:
            timeOfDay.text = NSLocalizedString("natt", comment: "time of day")
        case 6...8:
            timeOfDay.text = NSLocalizedString("morgon", comment: "time of day")
        case 9...11:
            timeOfDay.text = NSLocalizedString("förmiddag", comment: "time of day")
        case 12...17:
            timeOfDay.text = NSLocalizedString("eftermiddag", comment: "time of day")
        case 18...21:
            timeOfDay.text = NSLocalizedString("kväll", comment: "time of day")
        default:
            timeOfDay.text = nil
        }
        
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 12, 1...4:
            season.text = NSLocalizedString("vinter", comment: "season")
        case 5...6:
            season.text = NSLocalizedString("vår", comment: "season")
        case 7...8:
            season.text = NSLocalizedString("sommar", comment: "season")
        case 9...11:
            season.text = NSLocalizedString("höst", comment: "season")
        default:
            season.text = nil
        }
        
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        date.text = dateFormatter.string(from: Date())
    }
    
    // MARK: - Google ID Signin
    
    // Called when sign-in button pushed
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!,
              withError error: Error!) {
        if let error = error {
            showAlert(title: NSLocalizedString("Auktoriseringssfel", comment: "Fel password och liknande") , message: error.localizedDescription)
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
        
        contactEmail = []
        contactName = []
        contactPhoto = []
        
        // if let error = error {
        if error != nil {
            // Continue to fetch calendar items and display them without photos of the creator
            fetchEvents()
            // showAlert(title: "Error", message: error.localizedDescription)
            return
        }
        
        if let connections = response.connections, !connections.isEmpty {
            loop: for connection in connections {
                if let emailAddresses = connection.emailAddresses, !emailAddresses.isEmpty {
                    var email = ""
                    for address in emailAddresses {
                        if let _ = address.metadata?.primary {
                            email = address.value ?? ""
                        }
                    }
                    if email == "" { continue loop }
                    contactEmail.append(email)
                }
                
                if let names = connection.names, !names.isEmpty {
                    var displayName = ""
                    for name in names {
                        if let _ = name.metadata?.primary {
                            displayName = name.displayName ?? ""
                        }
                    }
                    contactName.append(displayName)
                }
                if let photos = connection.photos, !photos.isEmpty {
                    var url = ""
                    for photo in photos {
                        if let _ = photo.metadata?.primary {
                            url = photo.url ?? ""
                        }
                    }
                    contactPhoto.append(url)
                }
            }
        }
        fetchEvents()
    }
    
    // MARK: - Get Google Calendar Events
    
    // Construct a query and get a list of upcoming events from the user calendar
    private func fetchEvents() {
        let query = GTLRCalendarQuery_EventsList.query(withCalendarId: "primary")
        let startDate = Date()
        query.timeMin = GTLRDateTime(date: startDate)
        // 8 days of calendar data
        query.timeMax = GTLRDateTime(date: Date(timeInterval: 8 * 86400, since: startDate))
        
        query.singleEvents = true
        query.orderBy = kGTLRCalendarOrderByStartTime
        
        // Get calendar events in background
        DispatchQueue.global().async { [unowned self] in
            self.service.executeQuery(
                query,
                delegate: self,
                didFinish: #selector(self.displayResultWithTicket(ticket:finishedWithObject:error:)))
        }
    }
    
    // MARK: - Display events in TableView
    
    @objc func displayResultWithTicket(
        ticket: GTLRServiceTicket,
        finishedWithObject response : GTLRCalendar_Events,
        error : NSError?) {
        
        if let error = error {
            displayError(error: error.localizedDescription)
            return
        }
        
        if let events = response.items, !events.isEmpty {
            eventTitle = []
            eventDetail = []
            eventCreator = []
            
            for event in events {
                let start = (event.start!.dateTime ?? event.start!.date!).date
                let title = event.summary ?? ""
                eventTitle.append(getEventTitle(startDate: start, title: title))
                eventDetail.append(event.descriptionProperty ?? "")
                eventCreator.append(event.creator?.email ?? "")
            }
        } else {
            let start = Date()
            let title = NSLocalizedString("Inga kommande händelser", comment: "Message empty calendar")
            eventTitle = [getEventTitle(startDate: start, title: title)]
            eventDetail = [""]
            eventCreator = [""]
        }
        
        //  Get photos in background and when finished reload tableview from main queue
        DispatchQueue.global().async { [unowned self] in
            self.getCreatorPhotos()
            DispatchQueue.main.async {
                self.isRedBackground = false
                self.tableView.reloadData()
                // save results for possible later display if the connection to Google goes down
                self.oldEventTitle = self.eventTitle
                self.oldEventDetail = self.eventDetail
                self.oldEventPhoto = self.eventPhoto
            }
        }
    }
    
    private func getEventTitle(startDate start: Date, title: String) -> String {
        
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        var startDate = dateFormatter.string(from: start)
        startDate = String(startDate.dropLast(5)) // drop year
        
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short
        let startTime = dateFormatter.string(from: start)
        
        return startDate + " " + startTime + " - " + title
    }
    
    private func displayError(error: String) {
        eventTitle = oldEventTitle
        eventDetail = oldEventDetail
        eventPhoto = oldEventPhoto
        
        let start = Date()
        let title = NSLocalizedString("Fel. Kunde inte läsa kalendern.", comment: "Error message")
        eventTitle.insert(getEventTitle(startDate: start, title: title), at: 0)
        eventDetail.insert(NSLocalizedString("Följande händelser kanske inte längre är aktuella.", comment: "Error detail"), at: 0)
        eventPhoto.insert(nil, at: 0)
        
        isRedBackground = true
        tableView.reloadData()
    }
    
    // MARK: Get creator photos from Google contacts list
    
    private func getCreatorPhotos() {
        eventPhoto = []
        guard contactEmail != [] else { return }
        guard eventCreator != [] else { return }
        for creator in eventCreator {
            if let index = contactEmail.index(of: creator), creator != "" {
                let urlString = contactPhoto[index]
                if let url = URL(string: urlString), // also discards the case urlString == ""
                    let data = try? Data(contentsOf: url) {
                    eventPhoto.append(UIImage(data: data))
                } else {
                    eventPhoto.append(nil)
                }
            } else {
                eventPhoto.append(nil)
            }
        }
    }
    
    // MARK: - TableView Data Source
    
    // This returns 0 until (some) data has been retrieved from web. The 0 signals to TableView not to continue. Once all photos have been retrieved on background thread, tableView.reloadData is invoked on the main thread finishing populating the tableView
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return eventTitle.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! ViewCell
        
        let row = indexPath.row
        
        if row == 0 && isRedBackground == true {
            cell.backgroundColor = Color.red
        } else {
            cell.backgroundColor = nil
        }
        
        cell.headerLabel?.text = eventTitle[row]
        cell.descriptionLabel?.text = eventDetail[row]
        if eventPhoto.count == eventTitle.count {
            cell.creatorPhoto.image = eventPhoto[row]
        }
        cell.layoutIfNeeded()
        return cell
    }
    
    // MARK: - Showing Alert
    
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





