import Charts
import SwiftUI

struct LogPane: View {
    @EnvironmentObject private var store: DataStore
    @State private var showEditor = false
    @State private var editing: RoadLog?
    @State private var filter: SurfaceKind?

    var body: some View {
        let items = filtered
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                filterTab("ALL", active: filter == nil) { filter = nil }
                ForEach(SurfaceKind.allCases) { kind in
                    filterTab(kind.title.uppercased(), active: filter == kind) { filter = kind }
                }
            }
            .overlay(alignment: .bottom) { Rectangle().fill(Color("AppAccent").opacity(0.35)).frame(height: 1) }

            if store.routes.isEmpty {
                Spacer()
                Text("NO ROAD CONDITION HISTORY YET")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color("AppAccent"))
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            } else if items.isEmpty {
                Spacer()
                Text("FILTER EMPTY")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
            } else {
                List {
                    ForEach(items) { item in
                        Button {
                            editing = item
                            showEditor = true
                        } label: {
                            HStack(alignment: .top) {
                                Text(item.surface.title.prefix(1).uppercased())
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color("AppBackground"))
                                    .frame(width: 28, height: 28)
                                    .background(Color("AppAccent"))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(routeName(item.routeId).uppercased())
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                    Text(item.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.55))
                                    if !item.note.isEmpty {
                                        Text(item.note)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                                Spacer()
                                Text("\(item.temperature)°")
                                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color("AppAccent"))
                            }
                        }
                        .listRowBackground(Color.black.opacity(0.28))
                        .listRowSeparatorTint(Color("AppAccent").opacity(0.2))
                    }
                    .onDelete { indexSet in
                        indexSet.map { items[$0] }.forEach(store.deleteLog)
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
            }
            Button {
                editing = nil
                showEditor = true
            } label: {
                Text("+ LOG RIDE")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(store.routes.isEmpty ? Color.white.opacity(0.15) : Color("AppAccent"))
                    .foregroundColor(store.routes.isEmpty ? .white.opacity(0.4) : Color("AppBackground"))
            }
            .buttonStyle(.plain)
            .disabled(store.routes.isEmpty)
            .padding(12)
        }
        .sheet(isPresented: $showEditor, onDismiss: { editing = nil }) {
            LogEditorView(existing: editing)
        }
    }

    private var filtered: [RoadLog] {
        let base = store.logs
        if let filter { return base.filter { $0.surface == filter } }
        return base
    }

    private func routeName(_ id: UUID) -> String {
        store.routes.first(where: { $0.id == id })?.name ?? "Corridor"
    }

    private func filterTab(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(active ? Color("AppAccent") : Color.clear)
                .foregroundColor(active ? Color("AppBackground") : .white.opacity(0.6))
        }
        .buttonStyle(.plain)
    }
}

struct LogEditorView: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss
    var existing: RoadLog?
    @State private var routeId: UUID = UUID()
    @State private var date = Date()
    @State private var surface: SurfaceKind = .dry
    @State private var temperature = 12
    @State private var wind = 8
    @State private var note = ""
    @State private var error = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Corridor", selection: $routeId) {
                    ForEach(store.routes) { Text($0.name).tag($0.id) }
                }
                DatePicker("When", selection: $date, in: ...Date())
                Picker("Surface", selection: $surface) {
                    ForEach(SurfaceKind.allCases) { Text($0.title).tag($0) }
                }
                Stepper("Temperature \(temperature)°", value: $temperature, in: -15...40)
                Stepper("Wind \(wind)", value: $wind, in: 0...40)
                TextField("Annotation", text: $note)
                    .submitLabel(.done)
                    .onSubmit { Keyboard.dismiss() }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(NoteTemplate.allCases) { item in
                            Button {
                                toggleNote(item.rawValue)
                            } label: {
                                Text(item.rawValue.uppercased())
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(noteHas(item.rawValue) ? Color("AppAccent") : Color.white.opacity(0.08))
                                    .foregroundColor(noteHas(item.rawValue) ? Color("AppBackground") : .white.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !error.isEmpty { Text(error).foregroundColor(.red) }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(existing == nil ? "New log" : "Edit log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .onAppear {
                if let existing {
                    routeId = existing.routeId
                    date = existing.date
                    surface = existing.surface
                    temperature = existing.temperature
                    wind = existing.wind
                    note = existing.note
                } else if let selected = store.selectedRouteId {
                    routeId = selected
                } else if let first = store.routes.first {
                    routeId = first.id
                }
            }
        }
        .canvasBackground()
    }

    private func save() {
        if store.routes.isEmpty {
            error = "Add a corridor first."
            return
        }
        if date > Date() {
            error = "Future dates are not allowed."
            return
        }
        store.upsertLog(
            RoadLog(
                id: existing?.id ?? UUID(),
                routeId: routeId,
                date: date,
                surface: surface,
                temperature: temperature,
                wind: wind,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
        Haptics.success()
        dismiss()
    }

    private func noteHas(_ tag: String) -> Bool {
        note.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.contains(tag.lowercased())
    }

    private func toggleNote(_ tag: String) {
        var parts = note.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if let index = parts.firstIndex(where: { $0.lowercased() == tag.lowercased() }) {
            parts.remove(at: index)
        } else {
            parts.append(tag)
        }
        note = parts.joined(separator: ", ")
    }
}

struct InsightPane: View {
    @EnvironmentObject private var store: DataStore
    @State private var corridorId: UUID?
    @State private var compareLeft: UUID?
    @State private var compareRight: UUID?

    var body: some View {
        let series = scopedLogs
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ViewfinderCrop(image: "tile_ice", height: 80)
                if store.routes.isEmpty {
                    Text("NO RECORDED CONDITIONS YET — START YOUR JOURNEY SAFELY!")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(12)
                        .overlay(Bezel())
                } else {
                    corridorTabs
                    if series.isEmpty {
                        Text("NO PACKETS IN RANGE — LOG A RIDE TO PLOT STATS.")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(Bezel())
                    } else {
                        summaryStrip(series)
                        surfaceChart(series)
                        trendChart(series)
                        weekdayChart(series)
                        if corridorId == nil {
                            corridorChart
                        }
                    }
                    if store.routes.count >= 2 {
                        compareCard
                    }
                    ForEach(visibleRoutes) { route in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(route.name.uppercased())
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(store.predictedSurface(for: route.id).title.uppercased())
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color("AppAccent"))
                            }
                            RiskMeter(progress: store.riskScore(for: route.id))
                            Text(store.insightLine(for: route.id))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white.opacity(0.78))
                            Text(store.iceGapLine(for: route.id))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Color("AppPrimary"))
                            Text(store.bestWeekdayLine(for: route.id))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                            Text("RIDES \(store.logs(for: route.id).count)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        .padding(12)
                        .background(Color.black.opacity(0.38))
                        .overlay(Bezel())
                    }
                }
            }
            .padding(12)
        }
        .onAppear { syncCompare() }
        .onChange(of: store.routes.count) { _ in
            if let corridorId, !store.routes.contains(where: { $0.id == corridorId }) {
                self.corridorId = nil
            }
            syncCompare()
        }
    }

    private var scopedLogs: [RoadLog] {
        if let corridorId {
            return store.logs.filter { $0.routeId == corridorId }
        }
        return store.logs
    }

    private var visibleRoutes: [RideRoute] {
        if let corridorId {
            return store.routes.filter { $0.id == corridorId }
        }
        return store.routes
    }

    private var corridorTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                filterTab("ALL", active: corridorId == nil) { corridorId = nil }
                ForEach(store.routes) { route in
                    filterTab(route.name.uppercased(), active: corridorId == route.id) { corridorId = route.id }
                }
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Color("AppAccent").opacity(0.35)).frame(height: 1) }
    }

    private func syncCompare() {
        let ids = store.routes.map(\.id)
        if compareLeft == nil || compareLeft.map({ !ids.contains($0) }) == true {
            compareLeft = ids.first
        }
        if compareRight == nil || compareRight.map({ !ids.contains($0) }) == true {
            compareRight = ids.dropFirst().first
        }
        if compareLeft == compareRight, ids.count >= 2 {
            compareRight = ids.first(where: { $0 != compareLeft })
        }
    }

    private var compareCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CORRIDOR COMPARE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundColor(Color("AppAccent"))
            HStack(spacing: 8) {
                compareMenu(title: "A", selection: $compareLeft)
                compareMenu(title: "B", selection: $compareRight)
            }
            if let left = compareLeft, let right = compareRight, let duel = store.compareCorridors(leftId: left, rightId: right) {
                Text("DRIER  \(duel.drierName)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text("WARMER  \(duel.warmerName)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text(String(format: "%@  %d%% DRY  %+d°  n=%d", duel.leftName, Int((duel.leftDryShare * 100).rounded()), duel.leftAvgT, duel.leftCount))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                Text(String(format: "%@  %d%% DRY  %+d°  n=%d", duel.rightName, Int((duel.rightDryShare * 100).rounded()), duel.rightAvgT, duel.rightCount))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            } else {
                Text("PICK TWO CORRIDORS WITH LOGS TO COMPARE.")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.38))
        .overlay(Bezel())
    }

    private func compareMenu(title: String, selection: Binding<UUID?>) -> some View {
        Menu {
            ForEach(store.routes) { route in
                Button(route.name.uppercased()) { selection.wrappedValue = route.id }
            }
        } label: {
            HStack {
                Text(title)
                    .foregroundColor(Color("AppAccent"))
                Text(store.routes.first(where: { $0.id == selection.wrappedValue })?.name.uppercased() ?? "—")
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
            }
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .padding(10)
            .background(Color.black.opacity(0.35))
            .overlay(Bezel())
        }
    }

    private func filterTab(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(active ? Color("AppAccent") : Color.clear)
                .foregroundColor(active ? Color("AppBackground") : .white.opacity(0.6))
        }
        .buttonStyle(.plain)
    }

    private func summaryStrip(_ logs: [RoadLog]) -> some View {
        let avgT = Int((Double(logs.map(\.temperature).reduce(0, +)) / Double(logs.count)).rounded())
        let avgW = Int((Double(logs.map(\.wind).reduce(0, +)) / Double(logs.count)).rounded())
        let top = SurfaceKind.allCases.max(by: { a, b in
            logs.filter { $0.surface == a }.count < logs.filter { $0.surface == b }.count
        }) ?? .dry
        return HStack(spacing: 8) {
            statCell("RIDES", "\(logs.count)")
            statCell("AVG T", "\(avgT)°")
            statCell("AVG W", "\(avgW)")
            statCell("TOP", top.title.uppercased())
        }
    }

    private func statCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Color("AppAccent"))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.38))
        .overlay(Bezel())
    }

    private func surfaceChart(_ logs: [RoadLog]) -> some View {
        let slices = SurfaceKind.allCases.map { kind in
            SurfaceSlice(kind: kind, count: logs.filter { $0.surface == kind }.count)
        }
        return chartCard("SURFACE MIX") {
            Chart(slices) { slice in
                BarMark(
                    x: .value("Surface", slice.kind.title.uppercased()),
                    y: .value("Rides", slice.count)
                )
                .foregroundStyle(surfaceColor(slice.kind))
                .annotation(position: .top) {
                    if slice.count > 0 {
                        Text("\(slice.count)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
            }
            .chartXAxis { statAxisMarks() }
            .chartYAxis { statAxisMarks(leading: true) }
        }
    }

    private func trendChart(_ logs: [RoadLog]) -> some View {
        let points = Array(logs.sorted { $0.date < $1.date }.suffix(20)).flatMap { log in
            [
                TrendPoint(id: "t-\(log.id.uuidString)", date: log.date, value: log.temperature, metric: "TEMP"),
                TrendPoint(id: "w-\(log.id.uuidString)", date: log.date, value: log.wind, metric: "WIND")
            ]
        }
        return chartCard("TEMP / WIND") {
            Chart(points) { point in
                LineMark(
                    x: .value("When", point.date),
                    y: .value("Reading", point.value)
                )
                .foregroundStyle(by: .value("Metric", point.metric))
                .symbol(by: .value("Metric", point.metric))
                .interpolationMethod(.catmullRom)
            }
            .chartForegroundStyleScale([
                "TEMP": Color("AppAccent"),
                "WIND": Color("AppPrimary")
            ])
            .chartLegend(position: .top, alignment: .leading)
            .chartXAxis { statAxisMarks() }
            .chartYAxis { statAxisMarks(leading: true) }
        }
    }

    private func weekdayChart(_ logs: [RoadLog]) -> some View {
        let slices = store.weekdayDryCounts(from: logs)
        return VStack(alignment: .leading, spacing: 8) {
            chartCard("DRY BY WEEKDAY") {
                Chart(slices) { slice in
                    BarMark(
                        x: .value("Day", slice.name),
                        y: .value("Dry", slice.dry)
                    )
                    .foregroundStyle(Color("AppAccent"))
                }
                .chartXAxis { statAxisMarks() }
                .chartYAxis { statAxisMarks(leading: true) }
            }
            Text(store.bestWeekdayLine(from: logs))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 4)
        }
    }

    private var corridorChart: some View {
        let slices = store.routes.map { route in
            CorridorSlice(id: route.id, name: route.name.uppercased(), count: store.logs(for: route.id).count)
        }
        return chartCard("RIDES BY CORRIDOR") {
            Chart(slices) { slice in
                BarMark(
                    x: .value("Rides", slice.count),
                    y: .value("Corridor", slice.name)
                )
                .foregroundStyle(Color("AppAccent"))
            }
            .chartXAxis { statAxisMarks() }
            .chartYAxis { statAxisMarks(leading: true) }
        }
    }

    private func chartCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundColor(Color("AppAccent"))
            content()
                .frame(height: 168)
        }
        .padding(12)
        .background(Color.black.opacity(0.38))
        .overlay(Bezel())
    }

    private func statAxisMarks(leading: Bool = false) -> some AxisContent {
        AxisMarks(position: leading ? .leading : .bottom, values: .automatic(desiredCount: 4)) { _ in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                .foregroundStyle(Color.white.opacity(0.12))
            AxisValueLabel()
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.55))
        }
    }

    private func surfaceColor(_ kind: SurfaceKind) -> Color {
        switch kind {
        case .dry: return Color("AppAccent")
        case .wet: return Color("AppPrimary")
        case .icy: return Color.white.opacity(0.85)
        }
    }
}

private struct SurfaceSlice: Identifiable {
    let kind: SurfaceKind
    let count: Int
    var id: String { kind.rawValue }
}

private struct CorridorSlice: Identifiable {
    let id: UUID
    let name: String
    let count: Int
}

private struct TrendPoint: Identifiable {
    let id: String
    let date: Date
    let value: Int
    let metric: String
}

struct SettingsView: View {
    @EnvironmentObject private var store: DataStore
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("CFG")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(3)
                    .foregroundColor(Color("AppAccent"))
                TerminalRow(command: "RATE_US") { viewModel.rateApp() }
                TerminalRow(command: "PRIVACY") { viewModel.openPrivacy() }
                TerminalRow(command: "TERMS") { viewModel.openTerms() }
                Button {
                    viewModel.confirmReset = true
                } label: {
                    HStack {
                        Text(">")
                        Text("RESET_ALL_DATA")
                        Spacer()
                    }
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 12)
                    .overlay(Rectangle().stroke(Color("AppPrimary"), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
        }
        .confirmationDialog("Clear corridors, logs, and insight history?", isPresented: $viewModel.confirmReset, titleVisibility: .visible) {
            Button("Reset All Data", role: .destructive) { store.resetAllData() }
            Button("Cancel", role: .cancel) {}
        }
    }
}
