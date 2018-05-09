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
    
    private var contactEmail: [String] = []
    private var contactName: [String] = []
    private var contactPhoto: [String] = []
    
    let dateFormatter = DateFormatter()
    
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
    
    // If modifying these scopes, delete your previously saved credentials by
    // resetting the iOS simulator or uninstall the app.
    private let scopes = [kGTLRAuthScopeCalendarReadonly, kGTLRAuthScopePeopleServiceContactsReadonly]
    private let service = GTLRCalendarService()
    private let service2 = GTLRPeopleServiceService()
    let signInButton = GIDSignInButton()
    let output = UITextView()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure Google Sign-in.
        GIDSignIn.sharedInstance().delegate = self
        GIDSignIn.sharedInstance().uiDelegate = self
        GIDSignIn.sharedInstance().scopes = scopes
        GIDSignIn.sharedInstance().signInSilently()
        
        // Add the sign-in button.
        tableView.addSubview(signInButton)
        
        // Setup TableView
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 150
        
        // Setup ClockView and start clock
        let preferences = Preferences()
        let prepView = preferences.model.init(frame: subView.bounds)
        prepView.styleName = preferences.styleName
        clockView = prepView
        
        Timer.scheduledTimer(timeInterval: 0.25, target: self, selector: #selector(updateClock), userInfo: nil, repeats: true)
        
        // Setup and start Calendar
        // dateFormatter.locale = Locale(identifier: "sv")
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
    
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!,
              withError error: Error!) {
        if let error = error {
            showAlert(title: "Authentication Error", message: error.localizedDescription)
            self.service.authorizer = nil
        } else {
            self.signInButton.isHidden = true
            self.output.isHidden = false
            self.service.authorizer = user.authentication.fetcherAuthorizer()
            self.service2.authorizer = self.service.authorizer
            fetchContacts()
            Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(fetchContacts), userInfo: nil, repeats: true)
        }
    }
    
    // MARK: - Get Google Contacts
    
    @objc func fetchContacts() {
        let query = GTLRPeopleServiceQuery_PeopleConnectionsList.query(withResourceName: "people/me")
        query.personFields = "names,emailAddresses,photos"
        service2.executeQuery(
            query,
            delegate: self,
            didFinish: #selector(getContactsFromTicket(ticket:finishedWithObject:error:)))
    }
    
    @objc func getContactsFromTicket(
        ticket: GTLRServiceTicket,
        finishedWithObject response: GTLRPeopleService_ListConnectionsResponse,
        error: NSError?) {
        
        if let error = error {
            showAlert(title: "Error", message: error.localizedDescription)
            return
        }
        
        contactEmail = []
        contactName = []
        contactPhoto = []
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
    @objc func fetchEvents() {
        let query = GTLRCalendarQuery_EventsList.query(withCalendarId: "primary")
        // query.maxResults = 10
        query.timeMin = GTLRDateTime(date: Date())
        query.singleEvents = true
        query.orderBy = kGTLRCalendarOrderByStartTime
        service.executeQuery(
            query,
            delegate: self,
            didFinish: #selector(displayResultWithTicket(ticket:finishedWithObject:error:)))
    }
    
    // MARK: - Display events in TableView
    
    @objc func displayResultWithTicket(
        ticket: GTLRServiceTicket,
        finishedWithObject response : GTLRCalendar_Events,
        error : NSError?) {
        
        if let error = error {
            showAlert(title: "Error", message: error.localizedDescription)
            return
        }
        
        eventTitle = []
        eventDetail = []
        eventCreator = []
        if let events = response.items, !events.isEmpty {
            for event in events {
                let start = event.start!.dateTime ?? event.start!.date!
                
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .none
                var startDate = dateFormatter.string(from: start.date)
                startDate = String(startDate.dropLast(5))
                
                dateFormatter.dateStyle = .none
                dateFormatter.timeStyle = .short
                let startTime = dateFormatter.string(from: start.date)
                
                eventTitle.append(startDate + " " + startTime + " - " + (event.summary ?? ""))
                eventDetail.append(event.descriptionProperty ?? "")
                eventCreator.append(event.creator?.email ?? "")
            }
        } else {
            eventTitle = ["Inga kommande händelser"]
            eventDetail = [""]
            eventCreator = [""]
        }
        
        //  get photos in background and when finished reload tableview from main queue
        DispatchQueue.global().async { [unowned self] in
            self.getCreatorPhotos()
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    // MARK: Get creator photos from Google contacts list
    
    func getCreatorPhotos() {
        eventPhoto = []
        guard eventCreator != [] else { return }
        for creator in eventCreator {
            if let index = contactEmail.index(of: creator), creator != "" {
                let urlString = contactPhoto[index]
                if let url = URL(string: urlString), // also discards the case urlString = ""
                    let data = try? Data(contentsOf: url) {
                    eventPhoto.append(UIImage(data: data))
                } else { eventPhoto.append(nil) }
            } else { eventPhoto.append(nil) }
        }
    }
    
    // MARK: - TableView Data Source
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return eventTitle.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! ViewCell
        
        let row = indexPath.row
        cell.headerLabel?.text = eventTitle[row]
        cell.descriptionLabel?.text = eventDetail[row]
        cell.creatorPhoto.image = eventPhoto[row] // can be nil
        cell.layoutIfNeeded()
        return cell
    }
    
    // MARK: - Showing Alert
    
    func showAlert(title : String, message: String) {
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





