//
//  Speaker.swift
//  ClockMagic
//
//  Created by H Hugo Falkman on 2018-06-24.
//  Copyright © 2018 H Hugo Falkman. All rights reserved.
//

import UIKit
import AVFoundation

class Speaker: NSObject {

    // MARK: - "Public" API
    
    var userName: String?
    var speakTimeTimer: Timer?
    var speakEventTimer: Timer?
    
    func startSpeakTimeTimer() {
        guard TimingConstants.speechEnabled else { return }
        if let date = Calendar.autoupdatingCurrent.date(byAdding: .hour,
            value: TimingConstants.speakTimeHour, to: Date()) {
            let hour = Calendar.autoupdatingCurrent.component(.hour, from: date)
            if let firingDate = Calendar.autoupdatingCurrent.date(
                bySettingHour: hour, minute: 0, second: 1, of: date) {
                speakTimeTimer = Timer(fireAt: firingDate,
                    interval: Double(TimingConstants.speakTimeHour) * 3600.0, target: self,
                    selector: #selector(speakTime), userInfo: nil, repeats: true)
                RunLoop.current.add(speakTimeTimer!, forMode: .commonModes)
            }
        }
    }
    
    func speakTimeFirst() {
        guard TimingConstants.speechEnabled else { return }
        speakTime(first: true)
    }
    
    func checkSpeakEventTimer(events: [Event]) {
        guard TimingConstants.speechEnabled else { return }
        numberMinutes = Int(TimingConstants.speakEventNoticeTime / (60.0))
        let newEvents = findFirstEvents(events: events)
        guard newEvents.first != firstEvents.first else { return }
        firstEvents = newEvents
        if speakEventTimer != nil {
            speakEventTimer?.invalidate()
            speakEventTimer = nil
        }
        func startTimer() {
            guard let event = firstEvents.first else { return }
            let date = event.start - TimingConstants.speakEventNoticeTime
            dispatchGroupSpeech.enter()
            speakEventTimer = Timer(fireAt: date, interval: 0, target: self, selector: #selector(speakEvent), userInfo: nil, repeats: false)
            RunLoop.main.add(speakEventTimer!, forMode: .commonModes)
        }
        startTimer()
        
        dispatchGroupSpeech.notify(queue: .main) {
            self.firstEvents.removeFirst()
            startTimer()
        }
    }

    // MARK: - Properties
    
    private let synth = AVSpeechSynthesizer()
    private let dateFormatter = DateFormatter.shared
    
    private let dispatchGroupSpeech = DispatchGroup()
    private var firstEvents = [Event]()
    private var numberMinutes = 0
    
    // MARK: - Speech output
    
    @objc private func speakTime(first: Bool = false) {
        speakTimeTimer = nil
        let hello = NSLocalizedString("Hej %@, klockan är %@.", comment: "Hey name, it's time")
        var time = ""
        var date = Date()
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: date)
        
        if "sv" == Locale.autoupdatingCurrent.languageCode && !first {
            time = DateComponentsFormatter.localizedString(from:
                DateComponents(hour: (hour == 0) ? 24: hour), unitsStyle: .positional) ?? ""
        } else {
            dateFormatter.dateStyle = .none
            dateFormatter.timeStyle = .short
            if !first {
                date = Calendar.autoupdatingCurrent.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
            }
            time = dateFormatter.string(from: date)
        }
        
        let speech = String.localizedStringWithFormat(hello, userName ?? "", time)
        let language = Locale.autoupdatingCurrent.identifier
        let utterance = AVSpeechUtterance(string: speech as String)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        synth.speak(utterance)
    }
    
    @objc private func speakEvent() {
        speakEventTimer = nil
        let event = NSLocalizedString("Hej %@, om %d minuter: %@ -- %@.", comment: "Hey name, in x minutes: title -- detail")
        let speech = String.localizedStringWithFormat(event, userName ?? "", numberMinutes, firstEvents.first?.title ?? "", firstEvents.first?.detail ?? "")
        let language = Locale.autoupdatingCurrent.identifier
        let utterance = AVSpeechUtterance(string: speech as String)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        synth.speak(utterance)
        dispatchGroupSpeech.leave()
    }
    private func findFirstEvents(events: [Event]) -> [Event] {
        let eventsWithTime = events.filter { $0.hasTime }
        guard !eventsWithTime.isEmpty else { return []}
        
        func isNearEvent(event: Event) -> Bool {
            let noticeTimeInterval = event.start.timeIntervalSinceNow - TimingConstants.speakEventNoticeTime
            if noticeTimeInterval > 1 && noticeTimeInterval <
                max(TimingConstants.speakEventTimerMax, TimingConstants.eventTimer)  {
                return true
            } else { return false }
        }
        let earlyEvents = eventsWithTime.filter { isNearEvent(event: $0) }
        return earlyEvents
    }
}
