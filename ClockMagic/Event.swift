//
//  Event.swift
//  ClockMagic
//
//  Created by H Hugo Falkman on 2018-05-23.
//  Copyright © 2018 H Hugo Falkman. All rights reserved.
//

import Foundation

struct Event {
    var start: Date
    var hasTime: Bool
    var title: String
    var detail: String
    var creator: String
    var photo: UIImage?
    var attachId: String
    var attachTitle: String
    var attachPhoto: UIImage?
    
    private let dateFormatter = DateFormatter()
    
    init(start: Date, hasTime: Bool, summary: String, detail: String, creator: String) {
        self.start = start
        self.hasTime = hasTime
        self.detail = detail
        self.creator = creator
        self.attachId = ""
        self.attachTitle = ""
        
        self.title = summary
        if hasTime {
            dateFormatter.dateStyle = .none
            dateFormatter.timeStyle = .short
            self.title = dateFormatter.string(from: start) + " - " + summary
        }
    }
}





