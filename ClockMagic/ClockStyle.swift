//
//  ClockStyle.swift
//  ClockMagic
//
//  Created by H Hugo Falkman on 2018-04-30.
//  Copyright © 2018 H Hugo Falkman. All rights reserved.
//

import Foundation
import UIKit

protocol ClockStyle: CustomStringConvertible {
    var rawValue: String { get }
    var backgroundColor: UIColor { get }
    var faceColor: UIColor { get }
    var hourColor: UIColor { get }
    var minuteColor: UIColor { get }
    var secondColor: UIColor { get }
    var logoColor: UIColor { get }
    
    static var `default`: ClockStyle { get }
    static var all: [ClockStyle] { get }
}

extension ClockStyle {
    var backgroundColor: UIColor {
        return Color.darkBackground
    }
    var hourColor: UIColor {
        return minuteColor
    }
    var secondColor: UIColor {
        return Color.yellow
    }
    var logoColor: UIColor {
        return minuteColor
    }
}
