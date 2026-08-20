import Observation
import SwiftUI

/// A device found on the local network, plus why we may not be able to pair with it.
struct DiscoveryResult: Identifiable, Equatable {
    var bookmark: DeviceBookmark
    var blockedReason: String?

    var id: String { bookmark.id }
}

@MainActor
@Observable
final class DiscoverModel {
    private(set) var results: [DiscoveryResult] = []
    private(set) var isScanning = false

    private let client: NabtoClient

    init(client: NabtoClient = .shared) {
        self.client = client
    }

    /// Scan for two seconds, the window the app has always used, and inspect each hit as it arrives.
    func scan(knownDevices: Set<DeviceBookmark>) async {
        results = []
        isScanning = true
        defer { isScanning = false }

        for await device in client.discover(subType: "thermostat", duration: .seconds(2)) {
            let bookmark = DeviceBookmark(
                deviceId: device.deviceId,
                productId: device.productId,
                name: device.name ?? "Anonymous Thermostat"
            )
            guard !results.contains(where: { $0.bookmark == bookmark }) else { continue }
            results.append(DiscoveryResult(bookmark: bookmark, blockedReason: nil))

            let reason = await blockedReason(for: bookmark, knownDevices: knownDevices)
            if let index = results.firstIndex(where: { $0.bookmark == bookmark }) {
                results[index].blockedReason = reason
            }
        }
    }

    private func blockedReason(for bookmark: DeviceBookmark, knownDevices: Set<DeviceBookmark>) async -> String? {
        if knownDevices.contains(bookmark) {
            return "Device already paired with this client"
        }
        do {
            let modes = try await client.pairingModes(for: bookmark)
            // Password-invite pairing is not supported by this app.
            if modes.isEmpty || modes == [.passwordInvite] {
                return "No supported pairing modes are available on device"
            }
            return nil
        } catch {
            NSLog("Could not read pairing modes for \(bookmark.id): \(error)")
            return "Could not read pairing modes from device"
        }
    }
}

struct DiscoverView: View {
    @Binding var path: [Route]

    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(BannerCenter.self) private var banners

    @State private var model = DiscoverModel()

    var body: some View {
        List {
            if model.results.isEmpty {
                VStack(spacing: 8) {
                    if model.isScanning {
                        ProgressView()
                    }
                    Text("No thermostat devices found")
                        .font(.headline)
                    Text("""
                        Make sure you are on the same local area network as the device you try to \
                        discover and that the device is powered on.
                        """)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(model.results) { result in
                    Button {
                        select(result)
                    } label: {
                        DiscoveryRow(result: result)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Discover")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if model.isScanning {
                    ProgressView()
                } else {
                    Button("Scan again", systemImage: "arrow.clockwise") {
                        Task { await scan() }
                    }
                }
            }
        }
        .task { await scan() }
    }

    private func scan() async {
        await model.scan(knownDevices: Set(bookmarks.bookmarks))
    }

    private func select(_ result: DiscoveryResult) {
        if let reason = result.blockedReason {
            banners.show("Discover error", subtitle: reason, style: .danger)
        } else {
            path.append(.pairing(PairingTarget(bookmark: result.bookmark, password: nil)))
        }
    }
}

private struct DiscoveryRow: View {
    let result: DiscoveryResult

    var body: some View {
        HStack(spacing: 12) {
            Image("chip")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 32, height: 32)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.bookmark.name)
                    .font(.headline)
                Text(result.bookmark.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let reason = result.blockedReason {
                    Text(reason)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            Spacer(minLength: 0)

            Image(result.blockedReason == nil ? "open" : "alert")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(result.blockedReason == nil ? .green : .red)
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
    }
}
