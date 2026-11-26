import SwiftUI
@preconcurrency import MapKit
import RoutePilotCore

struct LocationSearchView: View {
    @ObservedObject var model: RoutePilotModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var searching = false
    @State private var message = "Search for a place or street address."
    @State private var task: Task<Void, Never>?
    @State private var generation = UUID()
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Place or address", text: $query).submitLabel(.search).onSubmit(search).autocorrectionDisabled().focused($searchFocused).accessibilityLabel("Place or address")
                        Button(action: search) { if searching { ProgressView() } else { Image(systemName: "magnifyingglass") } }.disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || searching).accessibilityLabel("Search")
                    }
                }
                if !message.isEmpty { Text(message).font(.subheadline).foregroundStyle(.secondary) }
                ForEach(Array(results.enumerated()), id: \.offset) { _, item in
                    Button {
                        model.add(RoutePoint(latitude: item.placemark.coordinate.latitude, longitude: item.placemark.coordinate.longitude), name: item.name)
                        model.fitRevision += 1
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name ?? "Location").foregroundStyle(.primary)
                            Text(item.placemark.title ?? "").font(.caption).foregroundStyle(.secondary)
                            Text(model.canEdit ? "Add checkpoint" : "Stop playback to add").font(.caption).foregroundStyle(.tint)
                        }
                    }.disabled(!model.canEdit)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Search locations").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }; ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { searchFocused = false } } }
            .onChange(of: query) { _, _ in
                generation = UUID(); task?.cancel(); searching = false; results = []; message = "Search for a place or street address."
            }
            .onDisappear { task?.cancel() }
        }
    }

    private func search() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 200 else { message = "Enter a place or address of up to 200 characters."; return }
        task?.cancel(); let revision = UUID(); generation = revision
        searchFocused = false
        searching = true; message = "Searching Apple Maps…"; results = []
        task = Task {
            do {
                let request = MKLocalSearch.Request(); request.naturalLanguageQuery = text
                let search = MKLocalSearch(request: request)
                let response = try await withThrowingTaskGroup(of: MKLocalSearch.Response.self) { group in
                    group.addTask { try await withTaskCancellationHandler(operation: { try await search.start() }, onCancel: { search.cancel() }) }
                    group.addTask { try await Task.sleep(for: .seconds(20)); throw RoutePilotError("Search timed out. Try again.") }
                    defer { group.cancelAll() }
                    guard let first = try await group.next() else { throw CancellationError() }
                    return first
                }
                try Task.checkCancellation()
                guard revision == generation else { return }
                results = Array(response.mapItems.prefix(15)); searching = false
                message = results.isEmpty ? "No results. Try a nearby town or a more specific address." : ""
            } catch is CancellationError { } catch {
                guard revision == generation else { return }
                searching = false; message = "Search unavailable. Check your connection, then retry."
            }
        }
    }
}
