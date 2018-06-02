//
//  MyUITableView.swift
//  ClockMagic
//
//  Created by H Hugo Falkman on 2018-06-02.
//  Copyright © 2018 H Hugo Falkman. All rights reserved.
//

import UIKit

class MyUITableView: UITableView {
    
    // Makes real device cell width available to test for in "cellForRowAt indexPath"
    override func dequeueReusableCell(withIdentifier identifier: String, for indexPath: IndexPath) -> UITableViewCell {
        let cell = super.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
        cell.frame.size.width = self.frame.size.width
        cell.layoutIfNeeded()
        return cell
    }
}
