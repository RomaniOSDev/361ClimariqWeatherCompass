import Foundation

enum SurfaceKind: String, Codable, CaseIterable, Identifiable {
    case dry
    case wet
    case icy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dry: return "Dry"
        case .wet: return "Wet"
        case .icy: return "Icy"
        }
    }

    var symbol: String {
        switch self {
        case .dry: return "sun.haze.fill"
        case .wet: return "drop.fill"
        case .icy: return "snowflake"
        }
    }
}

enum RideVerdict {
    case go
    case cautionWet
    case cautionFreeze
    case noGo
    case standby

    var code: String {
        switch self {
        case .go: return "GO — RIDE"
        case .cautionWet: return "CAUTION — WET"
        case .cautionFreeze: return "CAUTION — FREEZE"
        case .noGo: return "NO-GO — ICE"
        case .standby: return "STANDBY"
        }
    }
}

enum NoteTemplate: String, CaseIterable, Identifiable {
    case paintedLines = "painted lines"
    case metalCovers = "metal covers"
    case bridgeDeck = "bridge deck"

    var id: String { rawValue }
}

struct CorridorDuel {
    let leftName: String
    let rightName: String
    let leftDryShare: Double
    let rightDryShare: Double
    let leftAvgT: Int
    let rightAvgT: Int
    let leftCount: Int
    let rightCount: Int

    var drierName: String {
        if abs(leftDryShare - rightDryShare) < 0.001 { return "TIE" }
        return leftDryShare > rightDryShare ? leftName : rightName
    }

    var warmerName: String {
        if leftAvgT == rightAvgT { return "TIE" }
        return leftAvgT > rightAvgT ? leftName : rightName
    }
}

struct WeekdayDry: Identifiable {
    let weekday: Int
    let name: String
    let dry: Int
    let total: Int
    var id: Int { weekday }
}

struct RideRoute: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var neighborhood: String
    var watchChanges: Bool

    init(id: UUID = UUID(), name: String, neighborhood: String, watchChanges: Bool) {
        self.id = id
        self.name = name
        self.neighborhood = neighborhood
        self.watchChanges = watchChanges
    }
}

struct RoadLog: Identifiable, Codable, Equatable {
    var id: UUID
    var routeId: UUID
    var date: Date
    var surface: SurfaceKind
    var temperature: Int
    var wind: Int
    var note: String

    init(id: UUID = UUID(), routeId: UUID, date: Date, surface: SurfaceKind, temperature: Int, wind: Int, note: String) {
        self.id = id
        self.routeId = routeId
        self.date = date
        self.surface = surface
        self.temperature = temperature
        self.wind = wind
        self.note = note
    }
}
