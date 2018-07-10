//
//  Fonts.swift
//  ClockMagic
//
//  Created by H Hugo Falkman on 2018-07-10.
//  Copyright © 2018 H Hugo Falkman. All rights reserved.
//

import Foundation

struct Fonts {
    
    struct Clock {
        static let light = "HelveticaNeue-Light"
        static let regular = "HelveticaNeue"
        static let bold = "HelveticaNeue-Bold"
    }
    // Following fonts are dynamically changed if iOS 11.0 or later
    static let localCalendar = UIFont.systemFont(ofSize: 30, weight: .semibold)
    
    struct TableView {
        static let sectionHeader = UIFont.systemFont(ofSize: 25, weight: .medium)
        static let title = UIFont.systemFont(ofSize: 25, weight: .semibold)
        static let description = UIFont.systemFont(ofSize: 22, weight: .regular)
    }
    
    private init() {}
}
