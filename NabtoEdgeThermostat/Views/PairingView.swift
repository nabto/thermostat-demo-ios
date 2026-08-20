import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class PairingModel {
    private(set) var availableModes: [PairingModeKind]?
    private(set) var isPairing = false

    /// Shown once we know the device wants a password, or after one from a pairing string was
    /// rejected and the user should get a chance to correct it.
    private(set) var needsPassword = false

    var username: String
    var password: String

    private let target: PairingTarget
    private let client: NabtoClient

    /// A password that came from a pairing string is only ever tried once - if the device rejects
    /// it, we fall back to asking the user.
    private var pairingStringPassword: String?

    init(target: PairingTarget, client: NabtoClient = .shared) {
        self.target = target
        self.client = client
        self.username = UIDevice.current.name
        self.password = target.password ?? ""
        self.pairingStringPassword = target.password
    }

    var mode: PairingModeKind? {
        availableModes?.preferred
    }

    func loadPairingModes() async throws(PairingFailure) {
        do {
            let modes = try await client.pairingModes(for: target.bookmark)
            availableModes = modes
            if modes.isEmpty {
                throw PairingFailure.noPairingModesAvailable
            }
            guard let preferred = modes.preferred else {
                throw PairingFailure.unsupportedPairingMode
            }
            // Ask for a password up front rather than failing a pairing attempt first.
            if preferred == .passwordOpen, pairingStringPassword == nil {
                needsPassword = true
            }
        } catch let failure as PairingFailure {
            throw failure
        } catch {
            throw PairingFailure.deviceOffline
        }
    }

    /// Returns the bookmark enriched with what the device told us, ready to be named and saved.
    func pair() async throws(PairingFailure) -> DeviceBookmark {
        guard let mode else { throw PairingFailure.unsupportedPairingMode }

        isPairing = true
        defer { isPairing = false }

        let displayName = username
        let validUsername = Username.sanitize(username)
        let passwordToUse = pairingStringPassword ?? (password.isEmpty ? nil : password)

        do {
            return try await client.pair(
                with: target.bookmark,
                mode: mode,
                username: validUsername,
                displayName: displayName,
                password: passwordToUse
            )
        } catch let failure as PairingFailure {
            if failure == .authenticationFailed, pairingStringPassword != nil {
                // Do not retry with the pairing string's password; let the user type one.
                pairingStringPassword = nil
                needsPassword = true
            }
            throw failure
        } catch {
            throw PairingFailure.other("\(error)")
        }
    }
}

struct PairingView: View {
    let target: PairingTarget
    @Binding var path: [Route]

    @Environment(BannerCenter.self) private var banners

    @State private var model: PairingModel

    init(target: PairingTarget, path: Binding<[Route]>) {
        self.target = target
        self._path = path
        self._model = State(initialValue: PairingModel(target: target))
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(target.bookmark.name)
                        .font(.headline)
                    Text(target.bookmark.id)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text(model.needsPassword
                     ? "This device requires a password for pairing:"
                     : "You are about to pair with the above device.")
                    .font(.subheadline)

                LabeledContent("Your name") {
                    TextField("Your name", text: $model.username)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if model.needsPassword {
                    LabeledContent("Password") {
                        SecureField("Pairing password", text: $model.password)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            Section {
                Button {
                    Task { await pair() }
                } label: {
                    HStack {
                        if model.isPairing { ProgressView() }
                        Text("Pair with device")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(model.isPairing || model.mode == nil || model.username.isEmpty)
            }
        }
        .navigationTitle("Pair")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do throws(PairingFailure) {
                try await model.loadPairingModes()
            } catch {
                banners.show("Pairing Error", subtitle: error.userMessage, style: .danger)
            }
        }
    }

    private func pair() async {
        banners.dismiss()
        do {
            let paired = try await model.pair()
            path.append(.pairingConfirmed(paired))
        } catch {
            banners.show("Pairing Error", subtitle: error.userMessage, style: .danger)
        }
    }
}
