//
//  ViewController.swift
//  ClockMagic
//
//  Created by H Hugo Falkman on 2018-04-30.
//  Copyright © 2018 H Hugo Falkman. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    // MARK: - Properties
    
    private var clockView: ClockView? {
        willSet {
            let clockView = self.clockView
            clockView?.removeFromSuperview()
        }
        
        didSet {
            if let clockView = clockView {
                clockView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                view.addSubview(clockView)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let preferences = Preferences()
        let subview = preferences.model.init(frame: view.bounds)
        subview.styleName = preferences.styleName
        clockView = subview
        
        Timer.scheduledTimer(timeInterval: 0.25, target: self, selector: #selector(updateUI), userInfo: nil, repeats: true)
    }
    
    @objc private func updateUI() {
        if let clockView = clockView {
            clockView.
            clockView.setNeedsDisplay(clockView.clockFrame)
        }
    }
}





