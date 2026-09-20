import Foundation

extension Notification.Name {
    static let dataReset = Notification.Name("dataReset")
}

@MainActor
final class DataStore: ObservableObject {
    @Published var hasSeenOnboarding: Bool
    @Published var routes: [RideRoute]
    @Published var logs: [RoadLog]
    @Published var selectedRouteId: UUID?

    private let defaults = UserDefaults.standard
    private enum Key {
        static let onboarding = "hasSeenOnboarding"
        static let routes = "preferredRoutes"
        static let logs = "roadConditions"
        static let selected = "selectedRouteId"
    }

    init() {
        hasSeenOnboarding = defaults.bool(forKey: Key.onboarding)
        routes = Self.decode(key: Key.routes)
        logs = Self.decode(key: Key.logs)
        if let raw = defaults.string(forKey: Key.selected), let id = UUID(uuidString: raw) {
            selectedRouteId = id
        } else {
            selectedRouteId = routes.first?.id
        }
    }

    func completeOnboarding() {
        hasSeenOnboarding = true
        defaults.set(true, forKey: Key.onboarding)
    }

    func upsertRoute(_ item: RideRoute) {
        if let index = routes.firstIndex(where: { $0.id == item.id }) {
            routes[index] = item
        } else {
            routes.append(item)
        }
        persist(routes, key: Key.routes)
        selectedRouteId = item.id
        defaults.set(item.id.uuidString, forKey: Key.selected)
    }

    func deleteRoute(_ item: RideRoute) {
        routes.removeAll { $0.id == item.id }
        logs.removeAll { $0.routeId == item.id }
        persist(routes, key: Key.routes)
        persist(logs, key: Key.logs)
        if selectedRouteId == item.id {
            selectedRouteId = routes.first?.id
            defaults.set(selectedRouteId?.uuidString, forKey: Key.selected)
        }
    }

    func selectRoute(_ id: UUID) {
        selectedRouteId = id
        defaults.set(id.uuidString, forKey: Key.selected)
    }

    func upsertLog(_ item: RoadLog) {
        if let index = logs.firstIndex(where: { $0.id == item.id }) {
            logs[index] = item
        } else {
            logs.append(item)
        }
        logs.sort { $0.date > $1.date }
        persist(logs, key: Key.logs)
    }

    func deleteLog(_ item: RoadLog) {
        logs.removeAll { $0.id == item.id }
        persist(logs, key: Key.logs)
    }

    var selectedRoute: RideRoute? {
        routes.first(where: { $0.id == selectedRouteId }) ?? routes.first
    }

    func logs(for routeId: UUID) -> [RoadLog] {
        logs.filter { $0.routeId == routeId }
    }

    func predictedSurface(for routeId: UUID) -> SurfaceKind {
        let recent = Array(logs(for: routeId).prefix(3))
        guard !recent.isEmpty else { return .dry }
        if recent.contains(where: { $0.surface == .icy }) { return .icy }
        if recent.filter({ $0.surface == .wet }).count >= recent.filter({ $0.surface == .dry }).count {
            return .wet
        }
        return .dry
    }

    func riskScore(for routeId: UUID) -> Double {
        switch predictedSurface(for: routeId) {
        case .dry: return 0.22
        case .wet: return 0.62
        case .icy: return 0.92
        }
    }

    func insightLine(for routeId: UUID) -> String {
        let history = logs(for: routeId)
        guard !history.isEmpty else { return "Log a ride to unlock surface insight for this corridor." }
        let icy = history.filter { $0.surface == .icy }.count
        let wet = history.filter { $0.surface == .wet }.count
        if icy > 0 {
            return "Icy readings appear in \(icy) of \(history.count) logs. Slow the line and avoid painted markings."
        }
        if wet > history.count / 2 {
            return "Most recent rides were wet. Expect slick metal covers and longer braking."
        }
        return "Recent logs lean dry. Still scan bridges after night rain."
    }

    func freezeRisk(_ log: RoadLog) -> Bool {
        log.surface == .wet && log.temperature <= 2
    }

    func rideVerdict(for routeId: UUID) -> RideVerdict {
        guard let latest = logs(for: routeId).first else { return .standby }
        let predicted = predictedSurface(for: routeId)
        if predicted == .icy || latest.surface == .icy { return .noGo }
        if freezeRisk(latest) { return .cautionFreeze }
        if predicted == .wet || latest.surface == .wet { return .cautionWet }
        return .go
    }

    func verdictLine(for routeId: UUID) -> String {
        switch rideVerdict(for: routeId) {
        case .standby:
            return "Log a ride to unlock a go / no-go call."
        case .noGo:
            return "Icy readings on this corridor. Skip or walk the deck."
        case .cautionFreeze:
            if let latest = logs(for: routeId).first {
                return "Wet at \(latest.temperature)°. Overnight ice is likely."
            }
            return "Wet near freezing. Overnight ice is likely."
        case .cautionWet:
            return "Wet surface. Longer braking and slick metal covers."
        case .go:
            return "Recent logs lean dry. Still scan bridges after night rain."
        }
    }

    func suddenChange(for routeId: UUID) -> (from: SurfaceKind, to: SurfaceKind)? {
        let history = logs(for: routeId)
        guard history.count >= 2 else { return nil }
        let newest = history[0].surface
        let previous = history[1].surface
        guard newest != previous else { return nil }
        return (previous, newest)
    }

    @discardableResult
    func repeatLastLog(for routeId: UUID) -> Bool {
        guard let last = logs(for: routeId).first else { return false }
        upsertLog(
            RoadLog(
                id: UUID(),
                routeId: routeId,
                date: Date(),
                surface: last.surface,
                temperature: last.temperature,
                wind: last.wind,
                note: last.note
            )
        )
        return true
    }

    func iceGapLine(for routeId: UUID) -> String {
        let history = logs(for: routeId)
        guard !history.isEmpty else { return "Log a ride to start the ice gap." }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if let lastIcy = history.first(where: { $0.surface == .icy }) {
            let days = max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: lastIcy.date), to: today).day ?? 0)
            if days == 0 { return "ICY ON THE LATEST LOG" }
            return "\(days) DAY\(days == 1 ? "" : "S") WITHOUT ICY"
        }
        guard let oldest = history.min(by: { $0.date < $1.date }) else { return "Log a ride to start the ice gap." }
        let days = max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: oldest.date), to: today).day ?? 0)
        if days == 0 { return "NO ICY READINGS YET" }
        return "NO ICY IN \(days) DAY\(days == 1 ? "" : "S") OF LOGS"
    }

    func weekdayDryCounts(from history: [RoadLog]) -> [WeekdayDry] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let names = formatter.shortWeekdaySymbols ?? ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
        let calendar = Calendar.current
        var dry = Array(repeating: 0, count: 8)
        var total = Array(repeating: 0, count: 8)
        for log in history {
            let weekday = calendar.component(.weekday, from: log.date)
            total[weekday] += 1
            if log.surface == .dry { dry[weekday] += 1 }
        }
        return [2, 3, 4, 5, 6, 7, 1].map { weekday in
            WeekdayDry(
                weekday: weekday,
                name: names[weekday - 1].uppercased(),
                dry: dry[weekday],
                total: total[weekday]
            )
        }
    }

    func bestWeekdayLine(for routeId: UUID) -> String {
        bestWeekdayLine(from: logs(for: routeId))
    }

    func bestWeekdayLine(from history: [RoadLog]) -> String {
        let rows = weekdayDryCounts(from: history).filter { $0.total > 0 }
        guard history.count >= 2, let best = rows.max(by: { lhs, rhs in
            let left = Double(lhs.dry) / Double(lhs.total)
            let right = Double(rhs.dry) / Double(rhs.total)
            if left == right { return lhs.total < rhs.total }
            return left < right
        }) else {
            return "Log more rides to learn the driest weekday."
        }
        let percent = Int((Double(best.dry) / Double(best.total) * 100).rounded())
        return "DRIEST WEEKDAY \(best.name)  \(percent)% DRY"
    }

    func compareCorridors(leftId: UUID, rightId: UUID, limit: Int = 8) -> CorridorDuel? {
        guard leftId != rightId,
              let left = routes.first(where: { $0.id == leftId }),
              let right = routes.first(where: { $0.id == rightId }) else { return nil }
        let leftLogs = Array(logs(for: leftId).prefix(limit))
        let rightLogs = Array(logs(for: rightId).prefix(limit))
        guard !leftLogs.isEmpty, !rightLogs.isEmpty else { return nil }
        func dryShare(_ items: [RoadLog]) -> Double {
            Double(items.filter { $0.surface == .dry }.count) / Double(items.count)
        }
        func avgTemp(_ items: [RoadLog]) -> Int {
            Int((Double(items.map(\.temperature).reduce(0, +)) / Double(items.count)).rounded())
        }
        return CorridorDuel(
            leftName: left.name.uppercased(),
            rightName: right.name.uppercased(),
            leftDryShare: dryShare(leftLogs),
            rightDryShare: dryShare(rightLogs),
            leftAvgT: avgTemp(leftLogs),
            rightAvgT: avgTemp(rightLogs),
            leftCount: leftLogs.count,
            rightCount: rightLogs.count
        )
    }

    func resetAllData() {
        if let domain = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: domain)
        }
        hasSeenOnboarding = false
        routes = []
        logs = []
        selectedRouteId = nil
        NotificationCenter.default.post(name: .dataReset, object: nil)
    }

    private func persist<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private static func decode<T: Decodable>(key: String) -> [T] {
        guard let data = UserDefaults.standard.data(forKey: key), let value = try? JSONDecoder().decode([T].self, from: data) else {
            return []
        }
        return value
    }
}
