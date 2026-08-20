import SwiftUI

struct SettingsView: View {
    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(BannerCenter.self) private var banners

    @State private var confirmingKeypairReset = false
    @State private var confirmingClearDevices = false

    var body: some View {
        Form {
            Section {
                Button("Re-create keypair", role: .destructive) {
                    confirmingKeypairReset = true
                }
                Button("Clear device list", role: .destructive) {
                    confirmingClearDevices = true
                }
            }

            Section("About") {
                LabeledContent("Nabto Edge Client SDK", value: NabtoClient.sdkVersion)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Re-create profile",
            isPresented: $confirmingKeypairReset,
            titleVisibility: .visible
        ) {
            Button("Re-create keypair", role: .destructive) {
                Task {
                    await NabtoClient.shared.resetPrivateKey()
                    banners.show("Keypair removed", style: .success)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("""
                Are you sure you want to remove the currently active keypair? You must factory reset \
                devices that you are owner of to be owner again with the new key.
                """)
        }
        .confirmationDialog(
            "Clear device list",
            isPresented: $confirmingClearDevices,
            titleVisibility: .visible
        ) {
            Button("Clear device list", role: .destructive) {
                bookmarks.clear()
                banners.show("Device list cleared", style: .success)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to clear the list of known devices?")
        }
    }
}
