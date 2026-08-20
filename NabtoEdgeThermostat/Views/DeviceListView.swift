import Observation
import SwiftUI

@MainActor
@Observable
final class DeviceListModel {
    /// Device status keyed by ``DeviceBookmark/id``. A missing entry means "not probed yet".
    private(set) var statuses: [String: DeviceStatus] = [:]
    private(set) var isRefreshing = false

    private let client: NabtoClient

    init(client: NabtoClient = .shared) {
        self.client = client
    }

    func status(of bookmark: DeviceBookmark) -> DeviceStatus? {
        statuses[bookmark.id]
    }

    /// Probe every bookmarked device concurrently.
    func refresh(_ bookmarks: [DeviceBookmark]) async {
        isRefreshing = true
        defer { isRefreshing = false }

        statuses = [:]
        await withTaskGroup(of: (String, DeviceStatus).self) { group in
            for bookmark in bookmarks {
                group.addTask { [client] in (bookmark.id, await client.status(of: bookmark)) }
            }
            for await (id, status) in group {
                statuses[id] = status
            }
        }
    }

    /// Re-probe a single device, for when the user taps one we believe to be offline.
    func reprobe(_ bookmark: DeviceBookmark) async -> DeviceStatus {
        let status = await client.status(of: bookmark)
        statuses[bookmark.id] = status
        return status
    }

    func markOffline(_ bookmark: DeviceBookmark) {
        statuses[bookmark.id] = .offline
    }

    func markAllOffline() {
        for key in statuses.keys {
            statuses[key] = .offline
        }
    }

    /// Create the client keypair on first launch.
    func prepareProfile() async -> Bool {
        do {
            try await client.ensurePrivateKey()
            return true
        } catch {
            NSLog("Could not create private key: \(error)")
            return false
        }
    }
}

struct DeviceListView: View {
    @Binding var path: [Route]

    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(BannerCenter.self) private var banners

    @State private var model = DeviceListModel()
    @State private var isConnecting = false

    var body: some View {
        List {
            Section {
                if bookmarks.bookmarks.isEmpty {
                    EmptyDeviceListRow(isRefreshing: model.isRefreshing)
                } else {
                    ForEach(bookmarks.bookmarks) { bookmark in
                        Button {
                            select(bookmark)
                        } label: {
                            DeviceRow(bookmark: bookmark, status: model.status(of: bookmark))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section {
                Button {
                    path.append(.addDevice)
                } label: {
                    Label("Add device", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Devices")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if model.isRefreshing || isConnecting {
                    ProgressView()
                }
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await hardRefresh() }
                }
                .disabled(model.isRefreshing)
                Button("Settings", systemImage: "gearshape") { path.append(.settings) }
                Button("Help", systemImage: "questionmark.circle") { path.append(.help) }
            }
        }
        .task {
            guard await model.prepareProfile() else {
                banners.show("Error", subtitle: "Could not create private key", style: .danger)
                return
            }
            loadBookmarks()
            await model.refresh(bookmarks.bookmarks)
        }
        .task {
            for await event in NabtoClient.shared.events() {
                handle(event)
            }
        }
    }

    // MARK: - Actions

    private func loadBookmarks() {
        do {
            try bookmarks.load()
        } catch {
            banners.show("Error", subtitle: "Could not load bookmarks: \(error)", style: .danger)
        }
    }

    private func hardRefresh() async {
        banners.dismiss()
        await NabtoClient.shared.reset()
        await model.refresh(bookmarks.bookmarks)
    }

    private func select(_ bookmark: DeviceBookmark) {
        banners.dismiss()
        switch model.status(of: bookmark) {
        case let .paired(role):
            open(bookmark, role: role)
        case .unpaired:
            path.append(.pairing(PairingTarget(bookmark: bookmark, password: nil)))
        case .offline, .unavailable, .none:
            // Expect a timeout, so show activity while we try again.
            Task {
                isConnecting = true
                defer { isConnecting = false }
                switch await model.reprobe(bookmark) {
                case let .paired(role):
                    open(bookmark, role: role)
                case .unpaired:
                    path.append(.pairing(PairingTarget(bookmark: bookmark, password: nil)))
                case .offline:
                    banners.show("Error", subtitle: "Device '\(bookmark.name)' is offline")
                case let .unavailable(reason):
                    banners.show("Error", subtitle: "Cannot connect to '\(bookmark.name)': \(reason)")
                }
            }
        }
    }

    private func open(_ bookmark: DeviceBookmark, role: String?) {
        // Kept from the original app as guidance for anyone forking this demo: to support another
        // device type, branch on modelName here and push a different screen.
        let supportedModel = "ACME 9002 Thermostat"
        if let modelName = bookmark.modelName, modelName != supportedModel {
            NSLog("Warning: target device is of type \(modelName), this app only supports \(supportedModel)")
        }

        var updated = bookmark
        updated.role = role
        try? bookmarks.update(updated)
        path.append(.thermostat(updated))
    }

    private func handle(_ event: ClientEvent) {
        switch event {
        case let .connectionClosed(bookmark):
            model.markOffline(bookmark)
        case .networkLost:
            model.markAllOffline()
            banners.show("Network connection lost", subtitle: "Please try again later", style: .warning)
        case .networkAvailable:
            banners.show("Network up again!", style: .success)
            Task { await model.refresh(bookmarks.bookmarks) }
        }
    }
}

// MARK: - Rows

private struct DeviceRow: View {
    let bookmark: DeviceBookmark
    let status: DeviceStatus?

    var body: some View {
        HStack(spacing: 12) {
            Image("chip")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 32, height: 32)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(bookmark.name)
                    .font(.headline)
                Text(bookmark.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let role = bookmark.role {
                    Text(role)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            if let status {
                StatusIcon(status: status)
            } else {
                ProgressView()
            }
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

private struct StatusIcon: View {
    let status: DeviceStatus

    var body: some View {
        switch status {
        case .paired:
            icon("checkSmall", tint: .green, label: "Paired and online")
        case .unpaired:
            icon("open", tint: .green, label: "Open for pairing")
        case .offline, .unavailable:
            icon("alert", tint: .red, label: "Unavailable")
        }
    }

    private func icon(_ name: String, tint: Color, label: String) -> some View {
        Image(name)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: 20, height: 20)
            .foregroundStyle(tint)
            .accessibilityLabel(label)
    }
}

private struct EmptyDeviceListRow: View {
    let isRefreshing: Bool

    var body: some View {
        VStack(spacing: 8) {
            if isRefreshing {
                ProgressView()
            }
            Text("No known devices")
                .font(.headline)
            Text("Tap the add button below to scan the local network for available devices.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
