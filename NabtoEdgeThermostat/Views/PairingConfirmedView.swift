import SwiftUI

struct PairingConfirmedView: View {
    let bookmark: DeviceBookmark
    @Binding var path: [Route]

    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(BannerCenter.self) private var banners

    @State private var name: String

    init(bookmark: DeviceBookmark, path: Binding<[Route]>) {
        self.bookmark = bookmark
        self._path = path
        self._name = State(initialValue: bookmark.name)
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Image("check")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .foregroundStyle(.green)
                    Text("Congratulations! You are successfully paired!")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            Section("Name for this device in your list of devices:") {
                TextField("Enter the name of this device, e.g. \"Kitchen\".", text: $name)
            }

            Section {
                Button("Save") { save() }
                    .frame(maxWidth: .infinity)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("Successfully paired!")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
    }

    private func save() {
        var named = bookmark
        named.name = name.trimmingCharacters(in: .whitespaces)
        do {
            try bookmarks.add(named)
            path.removeAll()
        } catch {
            banners.show("Error", subtitle: "Could not save device: \(error)", style: .danger)
        }
    }
}
