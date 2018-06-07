//
//  EventDataSource.swift
//  ClockMagic
//
//  Created by H Hugo Falkman on 2018-06-07.
//  Copyright © 2018 H Hugo Falkman. All rights reserved.
//

import UIKit

class EventDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    
    // MARK: - "Public" API
    
    var eventsByDay = [[Event]]()
    var isRedBackground = false
    var currentDate = Date()
    
    // MARK: - Properties
    
    private let dateFormatter = DateFormatter()
    
    // MARK: - TableView Data Source/Delegate
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        guard !eventsByDay.isEmpty else { return nil }
        guard !eventsByDay[section].isEmpty else { return nil }
        
        let header = UILabel()
        header.font = UIFont.systemFont(ofSize: 25, weight: .medium)
        header.numberOfLines = 0
        header.lineBreakMode = .byWordWrapping
        header.sizeToFit()
        
        var day = currentDate
        switch section {
        case 0:
            header.text = NSLocalizedString("I dag", comment: "header")
        case 1:
            header.text = NSLocalizedString("I morgon", comment: "header")
            day = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        case 2:
            header.text = NSLocalizedString("I övermorgon", comment: "header")
            day = Calendar.current.date(byAdding: .day, value: 2, to: day)!
            
        default:
            header.text = "error"
        }
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        var formattedDay = dateFormatter.string(from: day)
        formattedDay = String(formattedDay.dropLast(5)) // drop year
        header.text = (header.text! + " " + formattedDay).uppercased()
        return header
    }
    
    // This returns 0 until (some) data has been retrieved from web. The 0 signals to TableView not to continue. Once all photos have been retrieved on background thread, tableView.reloadData is invoked on the main thread finishing populating the tableView
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        guard !eventsByDay.isEmpty else { return 0 }
        return eventsByDay[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! ViewCell
        let row = indexPath.row
        let section = indexPath.section
        
        if section == 0 && row == 0 && isRedBackground {
            cell.backgroundColor = Color.red
        } else if !eventsByDay[section][row].hasTime {
            cell.backgroundColor = Color.yellowBackground
        } else {
            cell.backgroundColor = nil
        }
        if let attach = eventsByDay[section][row].attachPhoto.first {
            let cellWidth = cell.attachPhoto.frame.size.width
            let scale = cellWidth / attach.size.width
            let size = CGSize(width: cellWidth, height: attach.size.height * scale)
            
            UIGraphicsBeginImageContextWithOptions(size, true, 0.0)
            attach.draw(in: CGRect(origin: CGPoint.zero, size: size))
            cell.attachPhoto.image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
        } else {
            cell.attachPhoto.image = nil
        }
        cell.headerLabel.text = eventsByDay[section][row].title
        cell.descriptionLabel.text = eventsByDay[section][row].detail
        cell.creatorPhoto.image = eventsByDay[section][row].photo
        return cell
    }
}
