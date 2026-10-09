//
//  CalendarGateEvaluator.swift
//

import Foundation

/// Compares calendar days in a fixed time zone (`dd.MM.yyyy` anchor).
struct CalendarGateEvaluator {

    let anchorDateString: String
    let timeZone: TimeZone

    init(
        anchorDateString: String = LaunchFlowSecrets.calendarGateAnchor,
        timeZone: TimeZone = .current
    ) {
        self.anchorDateString = anchorDateString
        self.timeZone = timeZone
    }

    /// `true` when reference day is on or after the anchor day (gate open).
    func isGateOpen(referenceDate: Date = Date()) -> Bool {
        guard let anchorDay = parseStartOfDay(anchorDateString) else {
            return false
        }
        let referenceDay = startOfDay(referenceDate)
        return referenceDay >= anchorDay
    }

    private func parseStartOfDay(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: text) else { return nil }
        return startOfDay(date)
    }

    private func startOfDay(_ date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.startOfDay(for: date)
    }
}
