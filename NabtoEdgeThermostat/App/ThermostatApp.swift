import SwiftUI

@main
struct ThermostatApp: App {
    @State private var bookmarks = BookmarkStore()
    @State private var banners = BannerCenter()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(bookmarks)
                .environment(banners)
        }
        .onChange(of: scenePhase) { _, phase in
            // Release the client and close connections cleanly rather than leaving the device with
            // dangling ones.
            if phase == .background {
                Task { await NabtoClient.shared.reset() }
            }
        }
    }
}

struct RootView: View {
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            DeviceListView(path: $path)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .addDevice:
                        AddDeviceView(path: $path)
                    case .discover:
                        DiscoverView(path: $path)
                    case let .pairing(target):
                        PairingView(target: target, path: $path)
                    case let .pairingConfirmed(bookmark):
                        PairingConfirmedView(bookmark: bookmark, path: $path)
                    case let .thermostat(bookmark):
                        ThermostatView(bookmark: bookmark)
                    case .settings:
                        SettingsView()
                    case .help:
                        HelpView()
                    }
                }
        }
        .bannerOverlay()
    }
}
