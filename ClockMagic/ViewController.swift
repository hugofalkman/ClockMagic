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

class ViewController: UIViewController, UITableViewDataSource,UITableViewDelegate, GIDSignInDelegate, GIDSignInUIDelegate {

    // MARK: - Properties
    
    @IBOutlet weak var subView: UIView!
  
    @IBOutlet weak var tableView: UITableView!
    
    private var eventTitle: [String] = []
    private var eventDetail: [String] = []
    private var eventCreator: [String] = []
    
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
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 100
        
        let preferences = Preferences()
        let subview = preferences.model.init(frame: subView.bounds)
        subview.styleName = preferences.styleName
        clockView = subview
        
        Timer.scheduledTimer(timeInterval: 0.25, target: self, selector: #selector(updateUI), userInfo: nil, repeats: true)
    }
    
    @objc private func updateUI() {
        if let clockView = clockView {
            clockView.setNeedsDisplay(clockView.clockFrame)
        }
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
            fetchEvents()
            Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(fetchEvents), userInfo: nil, repeats: true)
        }
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
    
    // MARK: - Get Google Contacts
    
    @objc func fetchContacts() {
        let query = GTLRPeopleServiceQuery_PeopleConnectionsList.query(withResourceName: "people/me")
        query.personFields = "names,emailAddresses,photos"
        service2.executeQuery(
            query,
            delegate: self,
            didFinish: #selector(getCreatorFromTicket(ticket:finishedWithObject:error:)))
    }
    
    @objc func getCreatorFromTicket(
        ticket: GTLRServiceTicket,
        finishedWithObject response: GTLRPeopleService_ListConnectionsResponse,
        error: NSError?) {
        
        if let error = error {
            showAlert(title: "Error", message: error.localizedDescription)
            return
        }
        
        if let connections = response.connections, !connections.isEmpty {
            for connection in connections {
                if let names = connection.names, !names.isEmpty {
                    for name in names {
                        if let _ = name.metadata?.primary {
                            print(name.displayName ?? "")
                        }
                    }
                }
                if let emailAddresses = connection.emailAddresses, !emailAddresses.isEmpty {
                    for email in emailAddresses {
                            if let _ = email.metadata?.primary {
                        print(email.value ?? "")
                        }
                    }
                }
                if let photos = connection.photos, !photos.isEmpty {
                    for photo in photos {
                        if let _ = photo.metadata?.primary {
                            print(photo.url ?? "")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Display events in TableView
    
    // Display the start dates and event summaries in the UITextView
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
                
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "sv")
                
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
        }
        tableView.reloadData()
    }
    
    // MARK: - TableView Data Source
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return eventTitle.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        let row = indexPath.row
        cell.textLabel?.text = eventTitle[row]
        cell.detailTextLabel?.text = eventDetail[row]
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





