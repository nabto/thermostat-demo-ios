import SwiftUI

struct AddDeviceView: View {
    @Binding var path: [Route]

    @State private var pairingString = ""

    private var parsed: PairingString? {
        try? PairingString.parse(pairingString)
    }

    var body: some View {
        Form {
            Section("Pair using a pairing string") {
                Text("Enter a pairing string to pair with any device, remote or local:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("p=pr-...,d=de-...,pwd=...", text: $pairingString, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.body.monospaced())

                if !pairingString.isEmpty, parsed == nil {
                    Label("Please enter a valid pairing string", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button("Pair using string") {
                    guard let parsed else { return }
                    path.append(.pairing(PairingTarget(bookmark: parsed.bookmark, password: parsed.password)))
                }
                .disabled(parsed == nil)

                Text("A pairing string is normally obtained from the owner of a device (who wants to invite guests).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Pair with a local device") {
                Text("If you don't know a pairing string, you can try to discover local devices to pair with:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Discover local devices") {
                    path.append(.discover)
                }
            }
        }
        .navigationTitle("Add device")
        .navigationBarTitleDisplayMode(.inline)
    }
}
