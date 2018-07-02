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
    static let speakTimeHour = 1
    static let speakEventTimerMax = 60 * 60.0
    static let cacheDisk = 200 * 1024 * 1024
    
    // Set by registerSettingsBundle method in ViewController
    static var saveAuthorization = false
    static var calendarEventMax = 0.0
    static var eventTimer = 0.0
    static var googleTimeout = 0.0
    static var speechEnabled = false
    static var speakEventNoticeTime = 0.0
    static var photoTimer = 0.0
    
    private init() {}
}
