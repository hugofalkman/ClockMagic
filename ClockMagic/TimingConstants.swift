//
//  TimingConstants.swift
//  ClockMagic
//
//  Created by H Hugo Falkman on 2018-06-25.
//  Copyright © 2018 H Hugo Falkman. All rights reserved.
//

import Foundation

struct TimingConstants {
    
    static let clockTimer = 0.25
    static let eventTimer = 5 * 60.0 // if >= speakTimeHour rewrite speaker speakTime
    static let photoTimer = 8.0
    static let speakTimeHour = 1
    static let speakEventTimerMax = 60 * 60.0
    static let speakEventNoticeTime = 10 * 60.0
    static let googleTimeout = 30.0
    static let calendarEventMax = 4.5 * 24 * 3600.0
    static let cacheDisk = 200 * 1024 * 1024
    
    private init() {}
}
