import SwiftUI

struct ForecastPane: View {
    @EnvironmentObject private var store: DataStore
    @State private var showRouteEditor = false
    @State private var editing: RideRoute?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ViewfinderCrop(image: "banner_storm", height: 88)

                if store.routes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NO CORRIDOR LOADED")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(Color("AppAccent"))
                        Text("Plan your ride safely — add your routes!")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.4))
                    .overlay(Bezel())
                } else {
                    VStack(spacing: 6) {
                        ForEach(store.routes) { route in
                            Button { store.selectRoute(route.id) } label: {
                                HStack {
                                    Text(store.selectedRouteId == route.id ? "■" : "□")
                                        .foregroundColor(Color("AppAccent"))
                                    Text(route.name.uppercased())
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text(route.neighborhood.uppercased())
                                        .foregroundColor(.white.opacity(0.45))
                                }
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .padding(10)
                                .background(store.selectedRouteId == route.id ? Color("AppPrimary").opacity(0.35) : Color.black.opacity(0.35))
                                .overlay(Bezel())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if let route = store.selectedRoute {
                        let surface = store.predictedSurface(for: route.id)
                        let latest = store.logs(for: route.id).first
                        let verdict = store.rideVerdict(for: route.id)
                        SignalCard(code: verdict.code, line: store.verdictLine(for: route.id), tint: verdictTint(verdict))

                        if route.watchChanges, let change = store.suddenChange(for: route.id) {
                            SignalCard(
                                code: "SUDDEN CHANGE",
                                line: "\(change.from.title.uppercased()) → \(change.to.title.uppercased()). Recheck this corridor before you roll.",
                                tint: Color("AppPrimary")
                            )
                        }

                        if let latest, store.freezeRisk(latest) {
                            SignalCard(
                                code: "FREEZE WATCH",
                                line: "Wet at \(latest.temperature)°. Overnight ice is likely on painted lines and metal covers.",
                                tint: Color.white
                            )
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            RiskMeter(progress: store.riskScore(for: route.id))
                            HStack {
                                Image(systemName: surface.symbol)
                                Text(surface.title.uppercased())
                            }
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(Color("AppAccent"))
                            Toggle("WATCH SUDDEN CHANGES", isOn: bindingWatch(route))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .tint(Color("AppAccent"))
                                .foregroundColor(.white)
                        }
                        .padding(12)
                        .background(Color.black.opacity(0.4))
                        .overlay(Bezel())

                        VStack(alignment: .leading, spacing: 6) {
                            Text("LATEST READING")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Color("AppAccent"))
                            if let latest {
                                Text(String(format: "T %+d  W %02d  %@", latest.temperature, latest.wind, latest.surface.title.uppercased()))
                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Text(latest.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.55))
                                Text(store.iceGapLine(for: route.id))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.7))
                                Text(store.bestWeekdayLine(for: route.id))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.7))
                                Button {
                                    if store.repeatLastLog(for: route.id) {
                                        Haptics.success()
                                    }
                                } label: {
                                    Text("REPEAT LAST LOG")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color("AppPrimary").opacity(0.35))
                                        .foregroundColor(.white)
                                        .overlay(Bezel())
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 4)
                            } else {
                                Text("NO PACKET")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.4))
                        .overlay(Bezel())
                    }
                }

                Button {
                    editing = nil
                    showRouteEditor = true
                } label: {
                    Text("+ ADD CORRIDOR")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color("AppAccent"))
                        .foregroundColor(Color("AppBackground"))
                }
                .buttonStyle(.plain)

                if let route = store.selectedRoute {
                    Button("EDIT SELECTED") {
                        editing = route
                        showRouteEditor = true
                    }
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color("AppAccent"))
                }
            }
            .padding(12)
        }
        .sheet(isPresented: $showRouteEditor) {
            RouteEditorView(existing: editing)
        }
    }

    private func bindingWatch(_ route: RideRoute) -> Binding<Bool> {
        Binding(
            get: { route.watchChanges },
            set: { value in
                var next = route
                next.watchChanges = value
                store.upsertRoute(next)
                Haptics.success()
            }
        )
    }

    private func verdictTint(_ verdict: RideVerdict) -> Color {
        switch verdict {
        case .go: return Color("AppAccent")
        case .cautionWet, .cautionFreeze: return Color("AppPrimary")
        case .noGo: return Color.white
        case .standby: return Color.white.opacity(0.55)
        }
    }
}

struct RouteEditorView: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss
    var existing: RideRoute?
    @State private var name = ""
    @State private var area = ""
    @State private var watch = true
    @State private var error = ""
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Corridor name", text: $name)
                    .submitLabel(.done)
                    .onSubmit { Keyboard.dismiss() }
                TextField("Neighborhood", text: $area)
                    .submitLabel(.done)
                    .onSubmit { Keyboard.dismiss() }
                Toggle("Watch sudden changes", isOn: $watch)
                if !error.isEmpty { Text(error).foregroundColor(.red) }
                if existing != nil {
                    Button("Delete corridor", role: .destructive) { confirmDelete = true }
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(existing == nil ? "New corridor" : "Edit corridor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .onAppear {
                if let existing {
                    name = existing.name
                    area = existing.neighborhood
                    watch = existing.watchChanges
                }
            }
            .confirmationDialog("Remove this corridor and its logs?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let existing { store.deleteRoute(existing) }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .canvasBackground()
    }

    private func save() {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = area.trimmingCharacters(in: .whitespacesAndNewlines)
        if n.isEmpty { error = "Name the corridor."; return }
        if a.isEmpty { error = "Add a neighborhood."; return }
        store.upsertRoute(RideRoute(id: existing?.id ?? UUID(), name: n, neighborhood: a, watchChanges: watch))
        Haptics.success()
        dismiss()
    }
}
