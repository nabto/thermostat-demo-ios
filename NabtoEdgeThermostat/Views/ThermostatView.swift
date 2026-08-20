import Observation
import SwiftUI

@MainActor
@Observable
final class ThermostatModel {
    private(set) var state: ThermostatState?
    private(set) var device: DeviceSummary?
    private(set) var user: UserSummary?

    /// True while a request is in flight, but only surfaced in the UI after a short delay so quick
    /// round trips do not flash a spinner.
    private(set) var showsActivity = false

    private(set) var autoRefreshing = false

    /// The value the slider is showing. Tracked separately from `state` so the user's drag is not
    /// fought by an auto-refresh landing mid-gesture.
    var target: Double = (ThermostatState.targetRange.lowerBound + ThermostatState.targetRange.upperBound) / 2

    private let bookmark: DeviceBookmark
    private let client: NabtoClient
    private var busyCount = 0
    private var activityTask: Task<Void, Never>?

    init(bookmark: DeviceBookmark, client: NabtoClient = .shared) {
        self.bookmark = bookmark
        self.client = client
    }

    // MARK: - Reading

    /// Poll the device until the surrounding task is cancelled, which SwiftUI does when the screen
    /// goes away. Replaces the repeating `Timer` the UIKit version used.
    func autoRefresh() async {
        autoRefreshing = true
        defer { autoRefreshing = false }
        while !Task.isCancelled {
            guard await refresh(userInitiated: false) else { return }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    /// Returns false if the device could not be reached, which stops auto-refresh.
    @discardableResult
    func refresh(userInitiated: Bool) async -> Bool {
        await withActivity(visible: userInitiated) {
            do {
                let fresh = try await client.thermostatState(for: bookmark)
                state = fresh
                // Only adopt the device's target when the user asked for a refresh; otherwise a poll
                // would yank the slider out from under them.
                if userInitiated {
                    target = fresh.target
                }
                if userInitiated || device == nil {
                    device = try await client.deviceSummary(for: bookmark)
                    user = try await client.currentUser(for: bookmark)
                }
                return true
            } catch {
                lastFailure = DeviceFailure.from(error)
                return false
            }
        }
    }

    /// Set by whichever operation failed last, for the view to turn into a banner.
    private(set) var lastFailure: DeviceFailure?

    func clearFailure() {
        lastFailure = nil
    }

    // MARK: - Writing

    func commitTarget() async {
        await update { try await client.setTarget(target, for: bookmark) }
    }

    func setPower(_ on: Bool) async {
        await update { try await client.setPower(on, for: bookmark) }
    }

    func setMode(_ mode: DeviceMode) async {
        await update { try await client.setMode(mode, for: bookmark) }
    }

    func reconnect() async {
        await client.reset()
        await refresh(userInitiated: true)
    }

    private func update(_ operation: () async throws -> Void) async {
        await withActivity(visible: true) {
            do {
                try await operation()
                await refresh(userInitiated: true)
            } catch {
                lastFailure = DeviceFailure.from(error)
                await client.disconnect(bookmark)
            }
        }
    }

    private func withActivity<T>(visible: Bool, _ work: () async -> T) async -> T {
        busyCount += 1
        if visible, activityTask == nil {
            activityTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled, let self, busyCount > 0 else { return }
                showsActivity = true
            }
        }
        defer {
            busyCount -= 1
            if busyCount == 0 {
                activityTask?.cancel()
                activityTask = nil
                showsActivity = false
            }
        }
        return await work()
    }
}

struct ThermostatView: View {
    let bookmark: DeviceBookmark

    @Environment(BannerCenter.self) private var banners

    @State private var model: ThermostatModel
    @State private var refreshTrigger = 0

    init(bookmark: DeviceBookmark) {
        self.bookmark = bookmark
        self._model = State(initialValue: ThermostatModel(bookmark: bookmark))
    }

    private var isActive: Bool { model.state?.power ?? false }

    var body: some View {
        Form {
            powerSection
            if isActive {
                targetSection
                modeSection
            }
            deviceSection
        }
        .navigationTitle(bookmark.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if model.autoRefreshing {
                    Text("auto-refreshing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        refreshTrigger += 1
                    }
                }
            }
        }
        .overlay {
            if model.showsActivity {
                ConnectingOverlay()
            }
        }
        // Restarting this task is how a manual refresh resumes auto-refresh after a failure.
        .task(id: refreshTrigger) {
            if refreshTrigger > 0 {
                await model.reconnect()
            }
            await model.autoRefresh()
        }
        .onChange(of: model.lastFailure) { _, failure in
            if let message = failure?.userMessage {
                banners.show("Communication Error", subtitle: message, style: .danger)
            }
            model.clearFailure()
        }
    }

    // MARK: - Sections

    private var powerSection: some View {
        Section {
            Toggle("Heatpump active", isOn: Binding(
                get: { isActive },
                set: { on in Task { await model.setPower(on) } }
            ))
            if !isActive {
                Text("Device not activated")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var targetSection: some View {
        Section {
            VStack(spacing: 12) {
                Text("\(pretty(model.target), specifier: "%.1f")ºC")
                    .font(.system(size: 56, weight: .light, design: .rounded))
                    .monospacedDigit()

                if let room = model.state?.temperature {
                    Text("\(pretty(room), specifier: "%.1f")ºC in room")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Image("cold")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(.blue)

                    Slider(
                        value: $model.target,
                        in: ThermostatState.targetRange,
                        onEditingChanged: { editing in
                            if !editing { Task { await model.commitTarget() } }
                        }
                    )

                    Image("hot")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(.red)
                }

                HStack {
                    Button("Colder", systemImage: "minus") { step(-1) }
                    Spacer()
                    Button("Warmer", systemImage: "plus") { step(+1) }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private var modeSection: some View {
        Section {
            Picker("Mode", selection: Binding(
                get: { model.state?.deviceMode ?? .heat },
                set: { mode in Task { await model.setMode(mode) } }
            )) {
                ForEach(DeviceMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
        }
    }

    private var deviceSection: some View {
        Section("Device information") {
            LabeledContent("Device", value: model.device?.displayId ?? bookmark.id)
            LabeledContent("Device app and version", value: model.device?.displayAppNameAndVersion ?? "n/a")
            LabeledContent("Username on device", value: model.user?.username ?? "n/a")
            LabeledContent("Display name on device", value: model.user?.displayName ?? "n/a")
            LabeledContent("Role on device", value: model.user?.role ?? "n/a")
        }
        .font(.footnote)
    }

    // MARK: - Helpers

    private func step(_ delta: Double) {
        let next = model.target + delta
        guard ThermostatState.targetRange.contains(next) else { return }
        model.target = next
        Task { await model.commitTarget() }
    }

    private func pretty(_ value: Double) -> Double {
        (value * 10.0).rounded() / 10.0
    }
}

private struct ConnectingOverlay: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Connecting to device...")
                .font(.subheadline)
        }
        .padding(24)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .shadow(radius: 12)
    }
}
