//
//  ViewController.swift
//  ClockMagic
//
//  Created by H Hugo Falkman on 2018-04-30.
//  Copyright © 2018 H Hugo Falkman. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UITableViewDataSource,UITableViewDelegate {

    // MARK: - Properties
    
    @IBOutlet weak var subView: UIView!
 
    @IBOutlet weak var tableView: UITableView!
    
    private var clockView: ClockView? {
        willSet {
            let clockView = self.clockView
            clockView?.removeFromSuperview()
        }
        
        didSet {
            if let clockView = clockView {
                clockView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                subView.addSubview(clockView)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        let preferences = Preferences()
        let subview = preferences.model.init(frame: subView.bounds)
        subview.styleName = preferences.styleName
        clockView = subview
        
        Timer.scheduledTimer(timeInterval: 0.25, target: self, selector: #selector(updateUI), userInfo: nil, repeats: true)
    }
    
    @objc private func updateUI() {
        if let clockView = clockView {
            clockView.setNeedsDisplay(clockView.clockFrame)
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        // let row = indexPath.row
        cell.textLabel?.text = "test"
        return cell
    }
}





