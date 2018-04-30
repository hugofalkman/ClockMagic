//
//  BN0032.swift
//  ClockMagic
//
//  Created by H Hugo Falkman on 2018-04-30.
//  Copyright © 2018 H Hugo Falkman. All rights reserved.
//

import Foundation
import UIKit

final class BN0032: ClockView {
    
    // MARK: - Types
    
    enum Style: String, ClockStyle {
        case bkbkg = "BKBKG"
        case whbkg = "WHBKG"
        
        var description: String {
            switch self {
            case .bkbkg:
                return "Black"
            case .whbkg:
                return "White"
            }
        }
        
        var faceColor: UIColor {
            switch self {
            case .bkbkg:
                return backgroundColor
            case .whbkg:
                return UIColor(white: 0.996, alpha: 1)
            }
        }
        
        var minuteColor: UIColor {
            switch self {
            case .bkbkg:
                return Color.white
            case .whbkg:
                return Color.black
            }
        }
        
        static var `default`: ClockStyle {
            return Style.bkbkg
        }
        
        static var all: [ClockStyle] {
            return [Style.bkbkg, Style.whbkg]
        }
    }
    
    // MARK: - ClockView
    
    override class var modelName: String {
        return "BN0032"
    }
    
    override var styleName: String {
        set {
            style = Style(rawValue: newValue) ?? Style.default
        }
        
        get {
            return style.description
        }
    }
    
    override class var styles: [ClockStyle] {
        return Style.all
    }
    
    override func initialize() {
        super.initialize()
        style = Style.default
    }
    
    override func draw(day: Int) {
        let dateArrowColor = Color.red
        let dateBackgroundColor = UIColor(red: 0.894, green: 0.933, blue: 0.965, alpha: 1)
        let clockWidth = clockFrame.size.width
        let dateWidth = clockWidth * 0.057416268
        let dateFrame = CGRect(
            x: clockFrame.origin.x + ((clockWidth - dateWidth) / 2.0),
            y: clockFrame.origin.y + (clockWidth * (1 - 0.199362041 - 0.071770335)),
            width: dateWidth,
            height: clockWidth * 0.071770335
        )
        
        dateBackgroundColor.setFill()
        
        UIRectFill(dateFrame)
        
        style.minuteColor.setFill()
        
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        
        let string = NSAttributedString(string: "\(day)", attributes: [
            .font: UIFont(name: "HelveticaNeue-Light", size: clockWidth * 0.044657098)!,
            .kern: -1,
            .paragraphStyle: paragraph
            ])
        
        var stringFrame = dateFrame
        stringFrame.origin.y += dateFrame.size.height * 0.12
        string.draw(in: stringFrame)
        
        dateArrowColor.setFill()
        let y = dateFrame.minY - (clockWidth * 0.015948963)
        let height = clockWidth * 0.022328549
        let pointDip = clockWidth * 0.009569378
        
        let path = UIBezierPath()
        path.move(to: CGPoint(x: dateFrame.minX, y: y))
        path.addLine(to: CGPoint(x: dateFrame.minX, y: y + height))
        path.addLine(to: CGPoint(x: dateFrame.midX, y: y + height + pointDip))
        path.addLine(to: CGPoint(x: dateFrame.maxX, y: y + height))
        path.addLine(to: CGPoint(x: dateFrame.maxX, y: y))
        path.addLine(to: CGPoint(x: dateFrame.midX, y: y + pointDip))
        path.fill()
    }
}
