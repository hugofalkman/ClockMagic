//
//  GoogleCalendar.swift
//  ClockMagic
//
//  Created by H Hugo Falkman on 2018-05-23.
//  Copyright © 2018 H Hugo Falkman. All rights reserved.
//

import Foundation
import GoogleAPIClientForREST
import GoogleSignIn

extension Notification.Name {
    static let EventsDidChange = Notification.Name("EventsDidChange")
    static let GoogleSignedIn = Notification.Name("GoogleSignedIn")
}

class GoogleCalendar: NSObject, GIDSignInDelegate {
    
    // MARK: - "Public" API (also sends above two notifications)
    
    private(set) var currentDate = Date()
    private(set) var events = [Event]()
    private(set) var eventsInError = false
    
    @objc func getEvents() {
        dispatchGroupContacts = DispatchGroup()
        
        fetchContacts()
        getCalendarList()
        
        dispatchGroupContacts.notify(queue: .main) {
            
            //  Get photos in background and when finished notify caller
            DispatchQueue.global().async { [unowned self] in
                self.getCreatorPhotos()
                DispatchQueue.main.async {
                    self.eventsInError = false
                    NotificationCenter.default.post(name: .EventsDidChange, object: self)
                }
            }
        }
    }
    
    func setupGIDSignIn() {
        // Configure Google Sign-in.
        GIDSignIn.sharedInstance().delegate = self
        GIDSignIn.sharedInstance().scopes = scopes
        GIDSignIn.sharedInstance().language = Locale.current.languageCode
        
        // Automatic Google Sign-in if access token saved in Keychain
        GIDSignIn.sharedInstance().signInSilently()
        
        // Configure GTLR services
        service.isRetryEnabled = true
        service.maxRetryInterval = 30
        service2.isRetryEnabled = true
        service2.maxRetryInterval = 30
    }
    
    // MARK: - GID SignIn Delegate
    
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!,
              withError error: Error!) {
        var userInfo = [String: Error]()
        if let error = error {
            userInfo["error"] = error
            self.service.authorizer = nil
            self.service.authorizer = nil
        } else {
            let accessToken = user.authentication.fetcherAuthorizer()
            self.service.authorizer = accessToken
            self.service2.authorizer = accessToken
        }
        NotificationCenter.default.post(name: .GoogleSignedIn,
            object: self, userInfo: userInfo)
    }
    
    // MARK: - Private properties and struct
    
    private let dateFormatter = DateFormatter()
    
    private var dispatchGroupContacts = DispatchGroup()
    private var dispatchGroupEvents = DispatchGroup()
    private var eventsSemaphore = DispatchSemaphore(value: 1)
    
    private struct Contact {
        var email: String
        var name: String
        var photoUrl: String
    }
    private var contacts = [Contact]()
    
    private var calendarIds = [String]()
    
    // Google GTLR framework
    // When scopes change, delete access token in Keychain by uninstalling the app
    private let scopes = [
        kGTLRAuthScopeCalendarReadonly,
        kGTLRAuthScopePeopleServiceContactsReadonly
    ]
    private let service = GTLRCalendarService()
    private let service2 = GTLRPeopleServiceService()
    
    // MARK: - Get Google Contacts
    
    private func fetchContacts() {
        let query = GTLRPeopleServiceQuery_PeopleConnectionsList.query(withResourceName: "people/me")
        query.personFields = "names,emailAddresses,photos"
        
        dispatchGroupContacts.enter()
        //  Runs in background
        service2.executeQuery(
            query,
            delegate: self,
            didFinish: #selector(self.getContactsFromTicket(ticket:finishedWithObject:error:)))
    }
    
    @objc private func getContactsFromTicket(
        ticket: GTLRServiceTicket,
        finishedWithObject response: GTLRPeopleService_ListConnectionsResponse,
        error: NSError?) {
        
        contacts = []
        if error != nil {
        // Continue fetching calendar events, just leaving them without photos of the creator
            dispatchGroupContacts.leave()
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
                
                var primaryName = ""
                if let names = connection.names, !names.isEmpty {
                    for name in names {
                        if let _ = name.metadata?.primary {
                            primaryName = name.displayName ?? ""
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
                
                contacts.append(Contact(email: email, name: primaryName, photoUrl: url))
            }
        }
        dispatchGroupContacts.leave()
    }
    
    // MARK: - Get list of Calendar ids
    
    private func getCalendarList() {
        currentDate = Date()
        calendarIds = []
        
        let query = GTLRCalendarQuery_CalendarListList.query()
        query.fields = "items/id"
        dispatchGroupContacts.enter()
        // Runs in background
        service.executeQuery(query) { (ticket, response, error) in
            
            if let error = error {
                // Flag error and return
                self.flagError(error: error.localizedDescription)
                return
            }
            
            if let list = response as? GTLRCalendar_CalendarList,
                let items = list.items {
                    for item in items where item.identifier != nil {
                        let calendarId = item.identifier!
                        self.calendarIds.append(calendarId)
                    }
            }
            
            if self.calendarIds.isEmpty {
                // Flag error and return
                self.flagError(error: NSLocalizedString("Inga kalendrar funna", comment: "Error message no calendars" ))
                return
            }
            
            DispatchQueue.main.async {
                self.fetchEvents()
            }
        }
    }
    
    // MARK: - Get Google Calendar Events
    
    private func fetchEvents() {
        
        events = []
        dispatchGroupEvents = DispatchGroup()
        eventsSemaphore = DispatchSemaphore(value: 1)
        
        // Set currentDate to reflect the start date of the query
        currentDate = Date()
        
        for calendarId in calendarIds {
            let query = GTLRCalendarQuery_EventsList.query(withCalendarId: calendarId)
            let startDate = currentDate
            query.timeMin = GTLRDateTime(date: startDate)
            // 48 hours of calendar data
            query.timeMax = GTLRDateTime(date: Date(timeInterval: 2 * 86400, since: startDate))
            query.fields = "items(start,summary,creator,description)"
            query.singleEvents = true
            query.orderBy = kGTLRCalendarOrderByStartTime
            
            dispatchGroupEvents.enter()
            // Runs in background
            service.executeQuery(query) { (ticket, response, error) in
                
                if let error = error {
                    // Flag error and return
                    self.flagError(error: error.localizedDescription)
                    return
                }
                
                if let list = response as? GTLRCalendar_Events,
                    let items = list.items, !items.isEmpty {
                        self.eventsSemaphore.wait()
                        for item in items {
                            // If hasTime is false, start.date is set to noon GMT
                            // to make day correct in all timezones
                            let start = item.start!.dateTime ?? item.start!.date!
                            let summary = item.summary ?? ""
                            let hasTime = start.hasTime
                            let creator = hasTime ? (item.creator?.email ?? "") : ""
                            self.events.append(Event(start: start.date, hasTime: hasTime, summary: summary, detail: item.descriptionProperty ?? "", creator: creator))
                        }
                        self.eventsSemaphore.signal()
                }
                self.dispatchGroupEvents.leave()
            }
        }
        
        dispatchGroupEvents.notify(queue: .main) {
            if self.events.isEmpty {
                let start = self.currentDate
                let summary = NSLocalizedString("Inga kommande händelser",
                    comment: "Message empty calendar")
                self.events = [Event(start: start, hasTime: true,
                    summary: summary, detail: "", creator: "")]
            }
            self.dispatchGroupContacts.leave()
        }
    }
    
    private func flagError(error: String) {
        eventsInError = true
        let userInfo = ["error": error]
        NotificationCenter.default.post(name: .EventsDidChange,
            object: self, userInfo: userInfo)
    }
    
    private func getCreatorPhotos() {
        guard !contacts.isEmpty else { return }
        guard !events.isEmpty else { return }
        let contactsEmail = contacts.map { $0.email }
        for eventIndex in events.indices {
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
}
