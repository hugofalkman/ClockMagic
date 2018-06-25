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

class MyUITableView: UITableView, UITableViewDataSource, UITableViewDelegate {
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        sectionHeaderHeight = UITableViewAutomaticDimension
        estimatedSectionHeaderHeight = 28
        dataSource = self
        delegate = self
    }
    
    // Makes real device cell width available in "cellForRowAt indexPath"
    override func dequeueReusableCell(withIdentifier identifier: String, for indexPath: IndexPath) -> UITableViewCell {
        let cell = super.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
        cell.frame.size.width = self.frame.size.width
        cell.layoutIfNeeded()
        return cell
    }
    
    // MARK: - "Public" API
    
    weak var photoTimer: Timer?
    
    func setup(events: [Event], isRedBackground isRed: Bool, currentDate: Date) {
        self.currentDate = currentDate
        isRedBackground = isRed
        
        eventsByDay = [[Event]](repeating: [], count: numberDays)
        let calendar = Calendar.autoupdatingCurrent
        for i in 0..<numberDays {
            let date = calendar.date(byAdding: .day, value: i, to: currentDate)
            eventsByDay[i] = events.filter { calendar.isDate($0.start, inSameDayAs: date!) }
        }
        reloadData()
        
        if !(events.filter { $0.attachPhoto.count > 1 }).isEmpty {
            if photoTimer == nil {
                photoTimer = Timer.scheduledTimer(timeInterval: TimingConstants.photoTimer,
                target: self, selector: #selector(updateSlideShow), userInfo: nil, repeats: true)
            }
        }
    }
    
    // MARK: - Properties
    
    private var eventsByDay = [[Event]]()
    private var isRedBackground = false
    private var currentDate = Date()
    private let dateFormatter = DateFormatter.shared
    private let numberDays = 1 + Int(ceil(TimingConstants.calendarEventMax / (24 * 3600.0)))
    
    // MARK: - SlideShow
    
    @objc private func updateSlideShow() {
        if let cells = visibleCells as? [ViewCell] {
            guard !cells.isEmpty else { return }
            var indexPaths = [IndexPath]()
            
            for cell in cells{
                if let indexPath = indexPath(for: cell) {
                    let section = indexPath.section
                    let row = indexPath.row
                    var photos = eventsByDay[section][row].attachPhoto
                    if photos.count > 1 {
                        indexPaths.append(indexPath)
                        photos.insert(photos.popLast()!, at: 0)
                        eventsByDay[section][row].attachPhoto = photos
                    }
                }
            }
            if !indexPaths.isEmpty {
                reloadRows(at: indexPaths, with: .right)
            }
        }
    }
    
    // MARK: - TableView Data Source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return numberDays
    }
    
    // This returns 0 until data has been retrieved from web. The 0 signals to TableView not to continue. Once events have been retrieved, tableView.reloadData is invoked populating the tableView.
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
            let cellWidth = cell.frame.size.width
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
    
    // MARK: - TableView Delegate
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        guard !eventsByDay.isEmpty else { return nil }
        guard !eventsByDay[section].isEmpty else { return nil }
        
        let header = UILabel()
        header.font = UIFont.systemFont(ofSize: 25, weight: .medium)
        header.numberOfLines = 0
        header.lineBreakMode = .byWordWrapping
        header.sizeToFit()
        
        switch section {
        case 0:
            header.text = NSLocalizedString("I dag", comment: "header")
        case 1:
            header.text = NSLocalizedString("I morgon", comment: "header")
        case 2:
            header.text = NSLocalizedString("I övermorgon", comment: "header")
        default:
            header.text = ""
        }
        
        let day = Calendar.current.date(byAdding: .day, value: section, to: currentDate)!
        dateFormatter.setLocalizedDateFormatFromTemplate("EEEE MMMM d")
        header.text = (header.text! + " " + dateFormatter.string(from: day)).uppercased()
        return header
    }
}
