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
    
    override init() {
        super.init()
        session = URLSession(configuration: .default)
    }
    
    // MARK: - "Public" API (also sends above two notifications)
    
    private(set) var currentDate = Date()
    private(set) var events = [Event]()
    private(set) var eventsInError = false
    
    @objc func getEvents() {
        dispatchGroupContacts = DispatchGroup()
        fetchContacts()
        getCalendarList()
        dispatchGroupContacts.notify(queue: .main) {
            //  Get contact photos and when finished notify caller
            self.getCreatorPhotos()
            self.dispatchGroupEvents.notify(queue: .main) {
                self.eventsInError = false
                NotificationCenter.default.post(name: .EventsDidChange, object: self)
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
        service.callbackQueue = DispatchQueue.global()
        service2.isRetryEnabled = true
        service2.maxRetryInterval = 30
        service2.callbackQueue = DispatchQueue.global()
        service3.isRetryEnabled = true
        service3.maxRetryInterval = 30
        service3.callbackQueue = DispatchQueue.global()
    }
    
    // MARK: - GID SignIn Delegate
    
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!,
              withError error: Error!) {
        var userInfo = [String: Error]()
        if let error = error {
            userInfo["error"] = error
            self.service.authorizer = nil
            self.service2.authorizer = nil
            self.service3.authorizer = nil
        } else {
            let authorizer = user.authentication.fetcherAuthorizer()
            self.service.authorizer = authorizer
            self.service2.authorizer = authorizer
            self.service3.authorizer = authorizer
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
    private var saveError: NSError?
    
    // Google GTLR framework
    // When scopes change, delete access token in Keychain by uninstalling the app
    private let scopes = [
        kGTLRAuthScopeCalendarReadonly,
        kGTLRAuthScopePeopleServiceContactsReadonly,
        kGTLRAuthScopeDriveReadonly
    ]
    private let service = GTLRCalendarService()
    private let service2 = GTLRPeopleServiceService()
    private let service3 = GTLRDriveService()
    
    private var session: URLSession?
    private var dataTask: URLSessionDataTask?
    
    // MARK: - Get Google Contacts
    
    private func fetchContacts() {
        let query = GTLRPeopleServiceQuery_PeopleConnectionsList.query(withResourceName: "people/me")
        query.personFields = "names,emailAddresses,photos"
        
        dispatchGroupContacts.enter()
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
        service.executeQuery(query) { (ticket, response, error) in
            if let error = error as NSError? {
                // Flag error and return
                self.flagError(error: error)
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
                let error = NSError(domain: "com.clockmagic.error", code: 999, userInfo: [NSLocalizedDescriptionKey : NSLocalizedString("Inga kalendrar funna", comment: "Error message no calendars" )])
                self.flagError(error: error)
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
        saveError = nil
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
            query.fields = "items(start,summary,creator,description,attachments(fileId,title))"
            query.singleEvents = true
            query.orderBy = kGTLRCalendarOrderByStartTime
            
            dispatchGroupEvents.enter()
            service.executeQuery(query) { (ticket, response, error) in
                if let error = error as NSError? {
                    // Save error and wait for other calendar Id background threads
                    self.eventsSemaphore.wait()
                    self.saveError = error
                    self.eventsSemaphore.signal()
                    self.dispatchGroupEvents.leave()
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
                            
                            var event = Event(start: start.date, hasTime: hasTime, summary: summary, detail: item.descriptionProperty ?? "", creator: creator)
                            
                            if let attachments = item.attachments, !attachments.isEmpty {
                                for attachment in attachments {
                                    if let fileId = attachment.fileId {
                                        event.attachId.append(fileId)
                                    }
                                }
                            }
                            self.events.append(event)
                        }
                        self.eventsSemaphore.signal()
                }
                self.dispatchGroupEvents.leave()
            }
        }
        dispatchGroupEvents.notify(queue: .main) {
            if let error = self.saveError {
                // Flag error and return
                self.flagError(error: error)
                return
            }
            if self.events.isEmpty {
                let start = self.currentDate
                let summary = NSLocalizedString("Inga kommande händelser",
                    comment: "Message empty calendar")
                self.events = [Event(start: start, hasTime: true,
                    summary: summary, detail: "", creator: "")]
            }
            self.getAttachmentPhotos()
        }
    }
    
    // MARK: - Get Calendar Attachment Photos from Google Drive
    
    private func getAttachmentPhotos() {
        guard !events.isEmpty else { return }
        
        for eventIndex in events.indices {
            let fileId = events[eventIndex].attachId
            if !fileId.isEmpty {
                for id in fileId {
                    let query = GTLRDriveQuery_FilesGet.queryForMedia(withFileId: id)
                    let downloadRequest = service3.request(for: query) as URLRequest
                    
                    let fetcher = service3.fetcherService.fetcher(with: downloadRequest)
                    fetcher.configuration = .default
                    fetcher.configurationBlock = { (fetcher, config) in
                        config.urlCache = URLCache(
                            memoryCapacity: 0,
                            diskCapacity: 200 * 1024 * 1024,
                            diskPath: "magic")
                        config.requestCachePolicy = .returnCacheDataElseLoad
                        config.timeoutIntervalForRequest = 30
                    }
                    dispatchGroupEvents.enter()
                    fetcher.beginFetch { (data, error) in
                        if error != nil {
                            print((error as NSError?)!.localizedDescription)
                            // Continue without adding photo to event
                            self.dispatchGroupEvents.leave()
                            return
                        }
                        self.eventsSemaphore.wait()
                        if let data = data, let photo = UIImage(data: data) {
                            self.events[eventIndex].attachPhoto.append(photo)
                        }
                        self.eventsSemaphore.signal()
                        self.dispatchGroupEvents.leave()
                    }
                }
            }
        }
        dispatchGroupEvents.notify(queue: .main) {
            self.dispatchGroupContacts.leave()
        }
    }
    
    // MARK: - Adding photos from Google Contacts to Google Calendar events
    
    private func getCreatorPhotos() {
        guard !contacts.isEmpty else { return }
        guard !events.isEmpty else { return }
        let contactsEmail = contacts.map { $0.email }
        for eventIndex in events.indices {
            if let index = contactsEmail.index(of: events[eventIndex].creator),
                events[eventIndex].creator != "" {
                let urlString = contacts[index].photoUrl
                if let url = URL(string: urlString) { // also discards the case urlString == ""
                    let urlRequest = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
                    dataTask = session?.dataTask(with: urlRequest) { (data, response, error) in
                        if error != nil {
                            print((error as NSError?)!.localizedDescription)
                            // Continue without adding photo to event
                            return
                        }
                        self.eventsSemaphore.wait()
                        if let data = data, let photo = UIImage(data: data) {
                            self.events[eventIndex].photo = photo
                        }
                        self.eventsSemaphore.signal()
                        self.dispatchGroupEvents.leave()
                    }
                    dispatchGroupEvents.enter()
                    // dispatchGroupEvents.notify up in "public" func getEvents
                    dataTask?.resume()
                } else {
                    events[eventIndex].photo = nil
                }
            } else {
                events[eventIndex].photo = nil
            }
        }
    }
    
    // MARK: - Returning Error
    
    private func flagError(error: NSError) {
        eventsInError = true
        let userInfo = ["error": error]
        NotificationCenter.default.post(name: .EventsDidChange,
                                        object: self, userInfo: userInfo)
    }
}
