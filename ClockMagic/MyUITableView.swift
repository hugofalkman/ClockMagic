//
//  MyUITableView.swift
//  ClockMagic
//
//  Created by H Hugo Falkman on 2018-06-02.
//  Copyright © 2018 H Hugo Falkman. All rights reserved.
//

import UIKit

// MARK: - TableView Cell

class ViewCell: UITableViewCell {
    
    @IBOutlet weak var creatorPhoto: UIImageView!
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var attachPhoto: UIImageView!
}

// MARK: - TableView

class MyUITableView: UITableView {
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.sectionHeaderHeight = UITableViewAutomaticDimension
        self.estimatedSectionHeaderHeight = 28
    }
    
    // Makes real device cell width available in "cellForRowAt indexPath"
    override func dequeueReusableCell(withIdentifier identifier: String, for indexPath: IndexPath) -> UITableViewCell {
        let cell = super.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
        cell.frame.size.width = self.frame.size.width
        cell.layoutIfNeeded()
        return cell
    }
}
