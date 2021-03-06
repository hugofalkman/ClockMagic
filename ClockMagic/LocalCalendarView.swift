//
//  LocalCalendarView.swift
//  ClockMagic
//
//  Created by H Hugo Falkman on 2018-06-25.
//  Copyright © 2018 H Hugo Falkman. All rights reserved.
//

import UIKit

class LocalCalendarView: UIStackView {
    
    // MARK: - Properties
    
    @IBOutlet private weak var dayOfWeekLabel: UILabel!
    @IBOutlet private weak var timeOfDayLabel: UILabel!
    @IBOutlet private weak var seasonLabel: UILabel!
    @IBOutlet private weak var dateLabel: UILabel!
    
    private let dateFormatter = DateFormatter.shared

    // MARK: - "Public" API
    
    func update(currentDate: Date) {
        
        var font = Fonts.localCalendar
        if #available(iOS 11.0, *) {
            let metrics = UIFontMetrics(forTextStyle: .body)
            font = metrics.scaledFont(for: font)
        }
            dayOfWeekLabel.font = font
            timeOfDayLabel.font = font
            seasonLabel.font = font
            dateLabel.font = font
        
        dateFormatter.formattingContext = .standalone
        dayOfWeekLabel.text = dateFormatter.weekdaySymbols[Calendar.autoupdatingCurrent.component(.weekday, from: currentDate) - 1].capitalized
        
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: currentDate)
        switch hour {
        case 22...23, 0...5:
            timeOfDayLabel.text = NSLocalizedString("natt", comment: "time of day")
        case 6...8:
            timeOfDayLabel.text = NSLocalizedString("morgon", comment: "time of day")
        case 9...11:
            timeOfDayLabel.text = NSLocalizedString("förmiddag", comment: "time of day")
        case 12...17:
            timeOfDayLabel.text = NSLocalizedString("eftermiddag", comment: "time of day")
        case 18...21:
            timeOfDayLabel.text = NSLocalizedString("kväll", comment: "time of day")
        default:
            timeOfDayLabel.text = nil
        }
        
        let monthday = Calendar.autoupdatingCurrent.dateComponents([.month, .day], from: currentDate)
        switch (monthday.month ?? 0, monthday.day ?? 0) {
        case (1...4, _), (12, _):
            seasonLabel.text = NSLocalizedString("vinter", comment: "season")
        case (5, _), (6, 1...15):
            seasonLabel.text = NSLocalizedString("vår", comment: "season")
        case (6, 16...30), (7...8, _):
            seasonLabel.text = NSLocalizedString("sommar", comment: "season")
        case (9...11, _):
            seasonLabel.text = NSLocalizedString("höst", comment: "season")
        default:
            seasonLabel.text = nil
        }
        seasonLabel.text = seasonLabel.text?.capitalized
        
        dateFormatter.setLocalizedDateFormatFromTemplate("MMMM d, YYYY")
        dateLabel.text = dateFormatter.string(from: currentDate)
    }
}
