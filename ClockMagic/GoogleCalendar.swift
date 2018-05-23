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

class GoogleCalendar {
    
    // MARK: - Public API
    
    var currentDate = Date()
    var events = [Event]()
    
    func getGoogleCalendarEvents(completionHandler: () -> Void) {
        
    }
    
    // MARK: - Private properties and struct
    
    private var myEvents = [Event]()
    private var oldEvents = [Event]()
    
    private struct Contact {
        var email: String
        var name: String
        var photoUrl: String
    }
    private var contacts = [Contact]()
    
    
}






