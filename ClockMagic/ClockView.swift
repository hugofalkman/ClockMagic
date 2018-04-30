//
//  ClockView.swift
//  ClockMagic
//
//  Created by H Hugo Falkman on 2018-04-30.
//  Copyright © 2018 H Hugo Falkman. All rights reserved.
//

import Foundation
import UIKit

class ClockView: UIView {
    
    // MARK: - Properties
    
    class var modelName: String {
        fatalError("Unimplemented")
    }
    
    var drawsLogo = false
    var logoImage: UIImage?
    var clockFrame: CGRect {
        return clockFrame(forBounds: bounds)
    }
    
    var fontName: String {
        return "HelveticaNeue-Light"
    }
    
    var style: ClockStyle!
    
    var styleName: String {
        set {
        }
        
        get {
            return style.description
        }
    }
    
    class var styles: [ClockStyle] {
        return []
    }
    
    override var frame: CGRect {
        didSet {
            setNeedsDisplay(bounds)
        }
    }
    
    // MARK: - Initializers
    
    convenience init() {
        self.init(frame: .zero)
    }
    
    required override init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initialize()
    }
    
    // MARK: - NSView
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        style.backgroundColor.setFill()
        UIRectFill(bounds)
        
        drawFaceBackground()
        drawTicks()
        drawNumbers()
        
        if drawsLogo {
            drawLogo()
        }
        
        let comps = Calendar.current.dateComponents([.day, .hour, .minute, .second], from: Date())
        let seconds = Double(comps.second ?? 0) / 60.0
        let minutes = (Double(comps.minute ?? 0) / 60.0) + (seconds / 60.0)
        let hours = (Double(comps.hour ?? 0) / 12.0) + ((minutes / 60.0) * (60.0 / 12.0))
        draw(day: comps.day ?? 0, hours: hours, minutes: minutes, seconds: seconds)
    }
    
    // MARK: - Configuration
    
    func initialize() {
        // NotificationCenter.default.addObserver(self, selector: #selector(preferencesDidChange), name: .PreferencesDidChange, object: nil)
        preferencesDidChange(nil)
    }
    
    func clockFrame(forBounds bounds: CGRect) -> CGRect {
        let size = bounds.size
        let clockSize = min(size.width, size.height) * 0.75
        
        let rect = CGRect(x: (size.width - clockSize) / 2.0, y: (size.height - clockSize) / 2.0, width: clockSize, height: clockSize)
        return rect.integral
    }
    
    // MARK: - Drawing Hooks
    
    func drawTicks() {
        drawTicksDivider(color: style.backgroundColor.withAlphaComponent(0.05), position: 0.074960128)
        
        let color = style.minuteColor
        drawTicks(minorColor: color.withAlphaComponent(0.5), minorLength: 0.049441786, minorThickness: 0.004784689, majorColor: color, majorThickness: 0.009569378, inset: 0.014)
    }
    
    func drawLogo() {
        drawLogo(color: style.logoColor, width: 0.156299841, y: 0.622009569)
    }
    
    func drawNumbers() {
        drawNumbers(fontSize: 0.071770334, radius: 0.402711324)
    }
    
    func draw(day: Int, hours: Double, minutes: Double, seconds: Double) {
        draw(day: day)
        draw(hours: (.pi * 2 * hours) - .pi / 2)
        draw(minutes: (.pi * 2 * minutes) - .pi / 2)
        draw(seconds: (.pi * 2 * seconds) - .pi / 2)
    }
    
    func draw(day: Int) {}
    
    func draw(hours angle: Double) {
        style.hourColor.setStroke()
        drawHand(length: 0.263955343, thickness: 0.023125997, angle: angle)
    }
    
    func draw(minutes angle: Double) {
        style.minuteColor.setStroke()
        drawHand(length: 0.391547049, thickness: 0.014354067, angle: angle)
    }
    
    func draw(seconds angle: Double) {
        style.secondColor.set()
        drawHand(length: 0.391547049, thickness: 0.009569378, angle: angle)
        
        // Counterweight
        drawHand(length: -0.076555024, thickness: 0.028708134, angle: angle, lineCapStyle: .round)
        let nubSize = clockFrame.size.width * 0.052631579
        let nubFrame = CGRect(x: (bounds.size.width - nubSize) / 2.0, y: (bounds.size.height - nubSize) / 2.0, width: nubSize, height: nubSize)
        UIBezierPath(ovalIn: nubFrame).fill()
        
        // Screw
        let dotSize = clockFrame.size.width * 0.006379585
        Color.black.setFill()
        let screwFrame = CGRect(x: (bounds.size.width - dotSize) / 2.0, y: (bounds.size.height - dotSize) / 2.0, width: dotSize, height: dotSize)
        let screwPath = UIBezierPath(ovalIn: screwFrame.integral)
        screwPath.fill()
    }
    
    
    // MARK: - Drawing Helpers
    
    func drawHand(length: Double, thickness: Double, angle: Double, lineCapStyle: CGLineCap = .square) {
        let center = CGPoint(x: clockFrame.midX, y: clockFrame.midY)
        let clockWidth = Double(clockFrame.size.width)
        let end = CGPoint(
            x: Double(center.x) + cos(angle) * clockWidth * length,
            y: Double(center.y) + sin(angle) * clockWidth * length
        )
        
        let path = UIBezierPath()
        path.lineWidth = CGFloat(clockWidth * thickness)
        path.lineCapStyle = lineCapStyle
        path.move(to: center)
        path.addLine(to: end)
        path.stroke()
    }
    
    func drawLogo(color: UIColor, width: CGFloat, y: CGFloat) {
//        if let image = logoImage {
//            let originalImageSize = image.size
//            let imageWidth = clockFrame.size.width * width
//            let imageSize = CGSize(
//                width: imageWidth,
//                height: originalImageSize.height * imageWidth / originalImageSize.width
//            )
//            let logoRect = CGRect(
//                x: (bounds.size.width - imageSize.width) / 2.0,
//                y: clockFrame.origin.y + (clockFrame.size.width * y),
//                width: imageSize.width,
//                height: imageSize.height
//            )
//
//            color.setFill()
//
//            let graphicsContext = UIGraphicsGetCurrentContext()!
//            // let cgImage = CGImage(forProposedRect: nil, context: graphicsContext, hints: nil)!
//            let context = graphicsContext
//
//            context.saveGState()
//            // context.clip(to: logoRect, mask: cgImage)
//            context.fill(bounds)
//            context.restoreGState()
//        }
    }
    
    func drawFaceBackground() {
        style.faceColor.setFill()
        
        let clockPath = UIBezierPath(ovalIn: clockFrame)
        clockPath.lineWidth = 4
        clockPath.fill()
    }
    
    func drawTicksDivider(color: UIColor, position: Double) {
        color.setStroke()
        let ticksFrame = clockFrame.insetBy(dx: clockFrame.size.width * CGFloat(position), dy: clockFrame.size.width * CGFloat(position))
        let ticksPath = UIBezierPath(ovalIn: ticksFrame)
        ticksPath.lineWidth = 1
        ticksPath.stroke()
    }
    
    func drawTicks(minorColor: UIColor, minorLength: Double, minorThickness: Double, majorColor _majorColor: UIColor? = nil, majorLength _majorLength: Double? = nil, majorThickness _majorThickness: Double? = nil, inset: Double = 0.0) {
        let majorColor = _majorColor ?? minorColor
        let majorLength = _majorLength ?? minorLength
        let majorThickness = _majorThickness ?? minorThickness
        let center = CGPoint(x: clockFrame.midX, y: clockFrame.midY)
        
        // Ticks
        let clockWidth = clockFrame.size.width
        let tickRadius = (clockWidth / 2.0) - (clockWidth * CGFloat(inset))
        for i in 0..<60 {
            let isMajor = (i % 5) == 0
            let tickLength = clockWidth * CGFloat(isMajor ? majorLength : minorLength)
            let progress = Double(i) / 60.0
            let angle = CGFloat((progress * .pi * 2) - .pi / 2)
            
            let tickColor = isMajor ? majorColor : minorColor
            tickColor.setStroke()
            
            let tickPath = UIBezierPath()
            tickPath.move(to: CGPoint(
                x: center.x + cos(angle) * (tickRadius - tickLength),
                y: center.y + sin(angle) * (tickRadius - tickLength)
            ))
            
            tickPath.addLine(to: CGPoint(
                x: center.x + cos(angle) * tickRadius,
                y: center.y + sin(angle) * tickRadius
            ))
            
            tickPath.lineWidth = CGFloat(ceil(Double(clockWidth) * (isMajor ? majorThickness : minorThickness)))
            tickPath.stroke()
        }
    }
    
    func drawNumbers(fontSize: CGFloat, radius: Double) {
        let center = CGPoint(x: clockFrame.midX, y: clockFrame.midY)
        
        let clockWidth = clockFrame.size.width
        let textRadius = clockWidth * CGFloat(radius)
        let font = UIFont(name: fontName, size: clockWidth * fontSize)!
        
        for i in 0..<12 {
            let string = NSAttributedString(string: "\(12 - i)", attributes: [
                .foregroundColor: style.minuteColor,
                .kern: -2,
                .font: font
                ])
            
            let stringSize = string.size()
            let angle = CGFloat(-(Double(i) / 12.0 * .pi * 2.0) - .pi / 2)
            let rect = CGRect(
                x: (center.x + cos(angle) * (textRadius - (stringSize.width / 2.0))) - (stringSize.width / 2.0),
                y: center.y + sin(angle) * (textRadius - (stringSize.height / 2.0)) - (stringSize.height / 2.0),
                width: stringSize.width,
                height: stringSize.height
            )
            
            string.draw(in: rect)
        }
    }
    
    // MARK: - Private
    
    @objc private func preferencesDidChange(_ notification: NSNotification?) {
        let preferences = (notification?.object as? Preferences) ?? Preferences()
        drawsLogo = preferences.drawsLogo
        
        if drawsLogo {
//            if let imageURL = Bundle(for: ClockView.self).url(forResource: "braun", withExtension: "pdf") {
//                logoImage = UIImage(contentsOf: imageURL)
//            }
        } else {
            logoImage = nil
        }
        
        setNeedsDisplay(bounds)
    }
}
