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
    
    private let dateFormatter = DateFormatter()
    
    init(start: Date, hasTime: Bool, summary: String, detail: String, creator: String) {
        self.start = start
        self.hasTime = hasTime
        self.detail = detail
        self.creator = creator
        self.photo = nil
        
        //        dateFormatter.dateStyle = .medium
        //        dateFormatter.timeStyle = .none
        //        var startDate = dateFormatter.string(from: start)
        //        startDate = String(startDate.dropLast(5)) // drop year
        
        guard hasTime else {
            self.title = summary
            return
        }
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short
        let startTime = dateFormatter.string(from: start)
        self.title = startTime + " - " + summary
        // self.title = startDate + " " + startTime + " - " + summary
    }
}
