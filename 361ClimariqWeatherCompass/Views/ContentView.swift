import SwiftUI

enum CompassPane: String, CaseIterable {
    case forecast
    case log
    case insight
    case settings

    var symbol: String {
        switch self {
        case .forecast: return "dot.scope"
        case .log: return "list.bullet.rectangle"
        case .insight: return "chart.bar.xaxis"
        case .settings: return "switch.2"
        }
    }

    var code: String {
        switch self {
        case .forecast: return "FCT"
        case .log: return "LOG"
        case .insight: return "STA"
        case .settings: return "CFG"
        }
    }
}

struct ContentView: View {
    @StateObject private var store = DataStore()
    @State private var pane: CompassPane = .forecast

    var body: some View {
        Group {
            if store.hasSeenOnboarding {
                HStack(spacing: 0) {
                    rail
                    VStack(spacing: 0) {
                        ticker
                        Group {
                            switch pane {
                            case .forecast: ForecastPane()
                            case .log: LogPane()
                            case .insight: InsightPane()
                            case .settings: SettingsView()
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .canvasBackground()
            } else {
                OnboardingView()
            }
        }
        .environmentObject(store)
        .preferredColorScheme(.dark)
    }

    private var rail: some View {
        VStack(spacing: 18) {
            ForEach(CompassPane.allCases, id: \.self) { item in
                Button {
                    pane = item
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 16, weight: .bold))
                        Text(item.code)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(pane == item ? Color("AppBackground") : Color.white.opacity(0.7))
                    .frame(width: 52, height: 52)
                    .background(pane == item ? Color("AppAccent") : Color.white.opacity(0.06))
                    .overlay(Rectangle().stroke(Color("AppAccent").opacity(pane == item ? 1 : 0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.top, 18)
        .padding(.horizontal, 8)
        .background(Color.black.opacity(0.55))
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color("AppAccent").opacity(0.4)).frame(width: 1)
        }
    }

    private var ticker: some View {
        HStack {
            Text("RD-COND // \(pane.code)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.4)
                .foregroundColor(Color("AppAccent"))
            Spacer()
            Text(Date().formatted(date: .omitted, time: .shortened))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.65))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.5))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color("AppAccent").opacity(0.35)).frame(height: 1)
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject private var store: DataStore
    @State private var page = 0
    private let pages = [
        ("Stay safe cycling", "Monitor corridor surface before the first pedal."),
        ("Check conditions", "Log dry, wet, or icy readings after each ride."),
        ("Get started now", "Add a route, then keep a private history of the road.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ViewfinderCrop(image: page == 0 ? "banner_storm" : (page == 1 ? "tile_ice" : "tile_rain"), height: 240)
            VStack(alignment: .leading, spacing: 10) {
                Text(String(format: "BOOT %02d/03", page + 1))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color("AppAccent"))
                Text(pages[page].0.uppercased())
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text(pages[page].1)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(20)
            Spacer()
            HStack {
                if page > 0 {
                    Button("BACK") { page -= 1 }
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                Spacer()
                Button(page == 2 ? "OPEN FCT" : "SKIP") {
                    store.completeOnboarding()
                }
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color("AppAccent"))
                .foregroundColor(Color("AppBackground"))
            }
            .padding(20)
        }
        .canvasBackground()
    }
}
