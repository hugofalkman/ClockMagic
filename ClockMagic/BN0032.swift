//
//  BN0032.swift
//  ClockMagic
//
//  Created by H Hugo Falkman on 2018-04-30.
//  Copyright © 2018 H Hugo Falkman. All rights reserved.
//

import UIKit

// final class BN0032: ClockView {
//
//    // MARK: - Types
//
//    enum Style: String, ClockStyle {
//        case bkbkg = "BKBKG"
//        // case whbkg = "WHBKG"
//
//        var description: String {
////            switch self {
////            case .bkbkg:
//                return "Black"
////            case .whbkg:
////                return "White"
////            }
//        }
//
//        var faceColor: UIColor {
////            switch self {
////            case .bkbkg:
//            return backgroundColor
////            case .whbkg:
////                return UIColor(white: 0.996, alpha: 1)
////            }
//        }
//
//        var minuteColor: UIColor {
////            switch self {
////            case .bkbkg:
//                return Color.white
////            case .whbkg:
////                return Color.black
////            }
//        }
//
//        static var `default`: ClockStyle {
//            return Style.bkbkg
//        }
//
//        static var all: [ClockStyle] {
//            return [Style.bkbkg]
//        }
//    }
    
    // MARK: - ClockView
    
//    override class var modelName: String {
//        return "BN0032"
//    }
//
//    override var styleName: String {
//        set {
//            style = Style(rawValue: newValue) ?? Style.default
//        }
//
//        get {
//            return style.description
//        }
//    }
//
//    override class var styles: [ClockStyle] {
//        return Style.all
//    }
//
//    override func initialize() {
//        super.initialize()
//        style = Style.default
//    }
//
//    override func draw(time: String) {
//        let timeBackgroundColor = UIColor(red: 0.894, green: 0.933, blue: 0.965, alpha: 1)
//        let clockWidth = clockFrame.size.width
//
//        let paragraph = NSMutableParagraphStyle()
//        paragraph.alignment = .center
//
//        let string = NSAttributedString(string: time, attributes: [
//            .font: UIFont(name: "HelveticaNeue-Bold", size: clockWidth * 0.09)!,
//            .kern: -1,
//            .paragraphStyle: paragraph
//            ])
//
//        var stringFrame = string.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: [.usesFontLeading, .usesLineFragmentOrigin], context: nil)
//        stringFrame.size.width += clockWidth * 0.04
//        stringFrame.origin.x = clockFrame.origin.x + ((clockWidth - stringFrame.size.width) / 2.0)
//        stringFrame.origin.y = clockFrame.origin.y + (clockWidth * 0.6)
//
//        timeBackgroundColor.setFill()
//        UIRectFill(stringFrame)
//
//        string.draw(in: stringFrame)
//    }
// }
