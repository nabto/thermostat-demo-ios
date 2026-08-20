import SwiftUI

struct HelpView: View {
    var body: some View {
        Form {
            Section("Pairing devices") {
                Text("""
                    A device must be paired with this app before you can control it. Pair either with a \
                    pairing string from the device's owner, or by discovering a device on your local \
                    network that is still open for pairing.
                    """)
            }

            Section("Discovering local devices") {
                Text("""
                    Make sure you are on the same local area network as the device you try to discover \
                    and that the device is powered on.
                    """)
            }

            Section("Roles") {
                LabeledContent("Owner") {
                    Text("Full control of the device, including managing which users may access it.")
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Guest") {
                    Text("May control the device but not manage its users.")
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("More help") {
                Link(
                    "docs.nabto.com",
                    destination: URL(string: "https://docs.nabto.com/developer/guides/platforms/ios/thermostat.html")!
                )
                Link("support@nabto.com", destination: URL(string: "mailto:support@nabto.com")!)
            }
        }
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
    }
}
