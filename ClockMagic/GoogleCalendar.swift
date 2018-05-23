//
//  GoogleCalendar.swift
//  ClockMagic
//
//  Created by H Hugo Falkman on 2018-05-23.
//  Copyright © 2018 H Hugo Falkman. All rights reserved.
//

import Foundation
import GoogleAPIClientForREST

extension Notification.Name {
    static let EventsDidChange = Notification.Name("EventsDidChange")
}

class GoogleCalendar: NSObject {
    
    // MARK: - Public API
    
    // Services configured and authorized by GID Signin in ViewController
    let service = GTLRCalendarService()
    let service2 = GTLRPeopleServiceService()
    
    var currentDate = Date()
    var events = [Event]()
    var eventsInError = false
    
    @objc func getEvents() {
        fetchContacts()
    }
    
    // MARK: - Private properties and struct
    
    private let dateFormatter = DateFormatter()
    
    private struct Contact {
        var email: String
        var name: String
        var photoUrl: String
    }
    private var contacts = [Contact]()
    
    // MARK: - Get Google Contacts
    
    private func fetchContacts() {
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
        // Continue to fetching calendar events, leaving them without photos of the creator
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
        fetchEvents()
    }
    
    // MARK: - Get Google Calendar Events
    
    // Construct a query and get a list of upcoming events from the user calendar
    private func fetchEvents() {
        
        // Set currentDate to reflect the start date of the query
        currentDate = Date()
        
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
            // Flag error and return
            flagError(error: error.localizedDescription)
            return
        }
        
        if let items = response.items, !items.isEmpty {
            events = []
            
            for item in items {
                // If hasTime is false, start.date is set to noon GMT
                // to make day correct in all timezones
                let start = item.start!.dateTime ?? item.start!.date!
                let summary = item.summary ?? ""
                let hasTime = start.hasTime
                let creator = hasTime ? (item.creator?.email ?? "") : ""
                events.append(Event(start: start.date, hasTime: hasTime, summary: summary, detail: item.descriptionProperty ?? "", creator: creator))
            }
        } else {
            let start = currentDate
            let summary = NSLocalizedString("Inga kommande händelser", comment: "Message empty calendar")
            events = [Event(start: start, hasTime: true,
                summary: summary, detail: "", creator: "")]
        }
        
        //  Get photos in background and when finished reload tableview from main queue
        DispatchQueue.global().async { [unowned self] in
            self.getCreatorPhotos()
            DispatchQueue.main.async {
                self.eventsInError = false
                NotificationCenter.default.post(name: .EventsDidChange, object: self)
           }
        }
    }
    
    private func flagError(error: String) {
        eventsInError = true
        NotificationCenter.default.post(name: .EventsDidChange, object: self)
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
