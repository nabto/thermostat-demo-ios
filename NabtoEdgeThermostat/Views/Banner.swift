import Observation
import SwiftUI

enum BannerStyle {
    case success, warning, danger

    var tint: Color {
        switch self {
        case .success: .green
        case .warning: .orange
        case .danger: .red
        }
    }

    var symbol: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .danger: "xmark.octagon.fill"
        }
    }
}

struct BannerMessage: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var subtitle: String?
    var style: BannerStyle

    static func == (lhs: BannerMessage, rhs: BannerMessage) -> Bool { lhs.id == rhs.id }
}

/// Transient status messages, shown at the top of the screen. One at a time, newest wins - the same
/// behaviour the app had when it used a third-party banner library.
@MainActor
@Observable
final class BannerCenter {
    private(set) var current: BannerMessage?

    @ObservationIgnored private var dismissal: Task<Void, Never>?

    func show(_ title: String, subtitle: String? = nil, style: BannerStyle = .danger) {
        show(BannerMessage(title: title, subtitle: subtitle, style: style))
    }

    func show(_ message: BannerMessage) {
        dismissal?.cancel()
        current = message
        dismissal = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissal?.cancel()
        current = nil
    }
}

private struct BannerOverlay: ViewModifier {
    @Environment(BannerCenter.self) private var banners

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message = banners.current {
                    BannerView(message: message)
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture { banners.dismiss() }
                }
            }
            .animation(.snappy, value: banners.current)
    }
}

private struct BannerView: View {
    let message: BannerMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: message.style.symbol)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(message.title)
                    .font(.subheadline.weight(.semibold))
                if let subtitle = message.subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(message.style.tint, in: .rect(cornerRadius: 12))
        .shadow(radius: 8, y: 4)
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// Apply once, at the root, so banners float above whatever is on screen.
    func bannerOverlay() -> some View {
        modifier(BannerOverlay())
    }
}
