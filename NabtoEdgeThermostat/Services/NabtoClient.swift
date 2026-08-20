import CBORCoding
import Foundation
import Network
@preconcurrency import NabtoEdgeClient
@preconcurrency import NabtoEdgeIamUtil

/// Something that happened outside of a request the user made.
enum ClientEvent: Sendable {
    case connectionClosed(DeviceBookmark)
    case networkLost
    case networkAvailable
}

/// The app's single point of contact with the Nabto Edge SDK.
///
/// Everything the SDK hands us — `Client`, `Connection`, `MdnsScanner`, `CoapResponse` — predates
/// Swift concurrency and is not `Sendable`. This actor owns all of it and never lets any of it
/// escape: every method here takes and returns plain value types, which is what lets the rest of the
/// app build cleanly in Swift 6 language mode.
actor NabtoClient {
    static let shared = NabtoClient()

    private let logLevel = "info"

    private var client: Client?
    private var connections: [DeviceBookmark: CachedConnection] = [:]

    private let monitor = NWPathMonitor()
    private var networkAvailable = true
    private var eventSubscribers: [UUID: AsyncStream<ClientEvent>.Continuation] = [:]

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let satisfied = path.status == .satisfied
            Task { await self?.networkPathChanged(satisfied: satisfied) }
        }
        monitor.start(queue: .global())
    }

    nonisolated static var sdkVersion: String {
        Client.versionString()
    }

    // MARK: - Events

    /// A multicast stream of connection and reachability events. Each caller gets its own stream;
    /// it is closed automatically when the consuming task ends.
    nonisolated func events() -> AsyncStream<ClientEvent> {
        AsyncStream { continuation in
            let id = UUID()
            Task { await self.subscribe(id: id, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.unsubscribe(id: id) }
            }
        }
    }

    private func subscribe(id: UUID, continuation: AsyncStream<ClientEvent>.Continuation) {
        eventSubscribers[id] = continuation
    }

    private func unsubscribe(id: UUID) {
        eventSubscribers.removeValue(forKey: id)
    }

    private func broadcast(_ event: ClientEvent) {
        for continuation in eventSubscribers.values {
            continuation.yield(event)
        }
    }

    private func networkPathChanged(satisfied: Bool) {
        guard satisfied != networkAvailable else { return }
        networkAvailable = satisfied
        broadcast(satisfied ? .networkAvailable : .networkLost)
    }

    private func connectionClosed(for bookmark: DeviceBookmark) {
        connections.removeValue(forKey: bookmark)?.detach()
        broadcast(.connectionClosed(bookmark))
    }

    // MARK: - Client life cycle

    /// Close every connection and tear the client down. Connections are closed cleanly rather than
    /// dropped, so the device does not end up with dangling connections.
    func reset() async {
        let cached = connections.values
        connections.removeAll()
        for entry in cached {
            entry.detach()
            try? await entry.connection.closeAsync()
            entry.connection.stop()
        }
        client?.stop()
        client = nil
    }

    func disconnect(_ bookmark: DeviceBookmark) async {
        guard let entry = connections.removeValue(forKey: bookmark) else { return }
        entry.detach()
        try? await entry.connection.closeAsync()
        entry.connection.stop()
    }

    private func sharedClient() throws -> Client {
        if let client { return client }
        let created = Client()
        created.enableNsLogLogging()
        try created.setLogLevel(level: logLevel)
        client = created
        NSLog("Initialized Nabto Edge Client SDK version \(Client.versionString())")
        return created
    }

    // MARK: - Client profile

    /// Ensure this client has a private key, creating and storing one on first launch.
    @discardableResult
    func ensurePrivateKey() throws -> String {
        if let existing = KeyStore.privateKey() { return existing }
        let created = try sharedClient().createPrivateKey()
        try KeyStore.save(created)
        return created
    }

    /// Discard the client's identity. Devices this client owns must be factory reset to be paired
    /// with the new key.
    func resetPrivateKey() async {
        await reset()
        KeyStore.clear()
    }

    // MARK: - Connections

    private func connection(for bookmark: DeviceBookmark) async throws -> Connection {
        if let cached = connections[bookmark] {
            return cached.connection
        }

        let connection = try sharedClient().createConnection()
        try connection.setProductId(id: bookmark.productId)
        try connection.setDeviceId(id: bookmark.deviceId)

        guard let privateKey = KeyStore.privateKey() else {
            throw ThermostatError.privateKeyMissing
        }
        try connection.setPrivateKey(key: privateKey)
        if let sct = bookmark.sct {
            try connection.setServerConnectToken(sct: sct)
        }

        try await connection.connectAsync()

        // The device proved it holds the key we saw at pairing time - or it is not the same device.
        if let expected = bookmark.deviceFingerprint,
           try connection.getDeviceFingerprintHex() != expected {
            connection.stop()
            throw ThermostatError.deviceIdentityChanged
        }

        let observer = ConnectionEventObserver { [weak self] event in
            guard event == .closed else { return }
            Task { await self?.connectionClosed(for: bookmark) }
        }
        try connection.addConnectionEventsReceiver(cb: observer)
        connections[bookmark] = CachedConnection(connection: connection, observer: observer)

        return connection
    }

    // MARK: - Thermostat

    func thermostatState(for bookmark: DeviceBookmark) async throws -> ThermostatState {
        let connection = try await connection(for: bookmark)
        let request = try connection.createCoapRequest(method: "GET", path: "/thermostat")
        let response = try await request.executeAsync()
        guard response.status == 205 else {
            throw ThermostatError.unexpectedStatus(path: "/thermostat", status: response.status)
        }
        do {
            return try CBORDecoder().decode(ThermostatState.self, from: response.payload)
        } catch {
            throw ThermostatError.decodingFailed("\(error)")
        }
    }

    func setTarget(_ celsius: Double, for bookmark: DeviceBookmark) async throws {
        try await post(path: "/thermostat/target", value: celsius, to: bookmark)
    }

    func setPower(_ on: Bool, for bookmark: DeviceBookmark) async throws {
        try await post(path: "/thermostat/power", value: on, to: bookmark)
    }

    func setMode(_ mode: DeviceMode, for bookmark: DeviceBookmark) async throws {
        try await post(path: "/thermostat/mode", value: mode.rawValue, to: bookmark)
    }

    private func post(path: String, value: some Encodable, to bookmark: DeviceBookmark) async throws {
        let payload = try CBOREncoder().encode(value)
        let connection = try await connection(for: bookmark)
        let request = try connection.createCoapRequest(method: "POST", path: path)
        try request.setRequestPayload(contentFormat: ContentFormat.APPLICATION_CBOR.rawValue, data: payload)
        let response = try await request.executeAsync()
        guard response.status == 204 else {
            throw ThermostatError.unexpectedStatus(path: path, status: response.status)
        }
    }

    // MARK: - Device and user info

    func deviceSummary(for bookmark: DeviceBookmark) async throws -> DeviceSummary {
        let details = try await IamUtil.getDeviceDetailsAsync(connection: connection(for: bookmark))
        return DeviceSummary(
            productId: details.ProductId,
            deviceId: details.DeviceId,
            appName: details.AppName,
            appVersion: details.AppVersion
        )
    }

    func currentUser(for bookmark: DeviceBookmark) async throws -> UserSummary {
        let user = try await IamUtil.getCurrentUserAsync(connection: connection(for: bookmark))
        return UserSummary(
            username: user.Username,
            displayName: user.DisplayName,
            role: user.Role,
            sct: user.Sct
        )
    }

    /// Probe a bookmarked device: is it reachable, and are we still paired with it?
    func status(of bookmark: DeviceBookmark) async -> DeviceStatus {
        do {
            let user = try await IamUtil.getCurrentUserAsync(connection: connection(for: bookmark))
            return user.Role != nil ? .paired(role: user.Role) : .unpaired
        } catch IamError.USER_DOES_NOT_EXIST {
            return .unpaired
        } catch ThermostatError.deviceIdentityChanged {
            return .unavailable("Device identity changed since pairing")
        } catch NabtoEdgeClientError.NO_CHANNELS {
            return .offline
        } catch {
            NSLog("Device \(bookmark.name) is not available due to error: \(error)")
            return .offline
        }
    }

    // MARK: - Pairing

    func pairingModes(for bookmark: DeviceBookmark) async throws -> [PairingModeKind] {
        let modes = try await IamUtil.getAvailablePairingModesAsync(connection: connection(for: bookmark))
        return modes.map(PairingModeKind.init)
    }

    /// Pair with a device and return the bookmark enriched with everything the device told us about
    /// itself. The caller is responsible for persisting it.
    func pair(
        with bookmark: DeviceBookmark,
        mode: PairingModeKind,
        username: String,
        displayName: String,
        password: String?
    ) async throws -> DeviceBookmark {
        do {
            let connection = try await connection(for: bookmark)

            switch mode {
            case .localInitial:
                try await IamUtil.pairLocalInitialAsync(connection: connection)
            case .localOpen:
                try await IamUtil.pairLocalOpenAsync(connection: connection, desiredUsername: username)
            case .passwordOpen:
                guard let password else { throw PairingFailure.authenticationFailed }
                try await IamUtil.pairPasswordOpenAsync(
                    connection: connection,
                    desiredUsername: username,
                    password: password
                )
            case .passwordInvite:
                throw PairingFailure.unsupportedPairingMode
            }

            await setDisplayName(displayName, for: username, on: connection)

            guard try await IamUtil.isCurrentUserPairedAsync(connection: connection) else {
                throw PairingFailure.other("device reported the pairing did not complete")
            }

            var paired = bookmark
            let user = try await IamUtil.getCurrentUserAsync(connection: connection)
            paired.role = user.Role
            paired.sct = user.Sct
            let details = try await IamUtil.getDeviceDetailsAsync(connection: connection)
            if let appName = details.AppName {
                paired.name = appName
            }
            paired.deviceFingerprint = try connection.getDeviceFingerprintHex()
            return paired
        } catch let failure as PairingFailure {
            throw failure
        } catch {
            throw PairingFailure(error)
        }
    }

    /// Best effort - not every device's IAM configuration allows setting a display name, and that is
    /// not a reason to fail the pairing.
    private func setDisplayName(_ displayName: String, for username: String, on connection: Connection) async {
        do {
            try await IamUtil.updateUserDisplayNameAsync(
                connection: connection,
                username: username,
                displayName: displayName
            )
        } catch IamError.BLOCKED_BY_DEVICE_CONFIGURATION {
            NSLog("Device IAM config does not support setting display name (tried \(displayName) for \(username))")
        } catch {
            NSLog("Unexpected error when setting display name: \(error)")
        }
    }

    // MARK: - Discovery

    /// Scan the local network for thermostat devices for `duration`, yielding each one as it turns up.
    nonisolated func discover(subType: String, duration: Duration) -> AsyncStream<DiscoveredDevice> {
        AsyncStream { continuation in
            let task = Task { await self.runScan(subType: subType, duration: duration, into: continuation) }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func runScan(
        subType: String,
        duration: Duration,
        into continuation: AsyncStream<DiscoveredDevice>.Continuation
    ) async {
        defer { continuation.finish() }
        do {
            let scanner = try sharedClient().createMdnsScanner(subType: subType)
            let observer = MdnsObserver { continuation.yield($0) }
            scanner.addMdnsResultReceiver(observer)
            try scanner.start()
            try? await Task.sleep(for: duration)
            scanner.stop()
            scanner.removeMdnsResultReceiver(observer)
        } catch {
            NSLog("Could not start mDNS scan: \(error)")
        }
    }
}

// MARK: - SDK callback adapters

/// The SDK's callback protocols are `@objc` and predate Swift concurrency. These adapters are the
/// only place SDK callbacks are received; each maps its payload to a `Sendable` value *before*
/// handing it on, so nothing SDK-specific ever crosses an isolation boundary.
private final class ConnectionEventObserver: NSObject, ConnectionEventReceiver, @unchecked Sendable {
    enum Event { case connected, closed, channelChanged, unexpected }

    private let handler: @Sendable (Event) -> Void

    init(handler: @escaping @Sendable (Event) -> Void) {
        self.handler = handler
    }

    func onEvent(event: NabtoEdgeClientConnectionEvent) {
        let mapped: Event = switch event {
        case .CONNECTED: .connected
        case .CLOSED: .closed
        case .CHANNEL_CHANGED: .channelChanged
        case .UNEXPECTED_EVENT: .unexpected
        @unknown default: .unexpected
        }
        handler(mapped)
    }
}

private final class MdnsObserver: NSObject, MdnsResultReceiver, @unchecked Sendable {
    private let handler: @Sendable (DiscoveredDevice) -> Void

    init(handler: @escaping @Sendable (DiscoveredDevice) -> Void) {
        self.handler = handler
    }

    func onResultReady(result: MdnsResult) {
        guard result.action == .ADD,
              let productId: String = result.productId,
              let deviceId: String = result.deviceId
        else {
            return
        }
        handler(DiscoveredDevice(productId: productId, deviceId: deviceId, name: result.txtItems["fn"]))
    }
}

/// A live connection plus the observer keeping it under watch.
private final class CachedConnection {
    let connection: Connection
    private let observer: ConnectionEventObserver

    init(connection: Connection, observer: ConnectionEventObserver) {
        self.connection = connection
        self.observer = observer
    }

    func detach() {
        connection.removeConnectionEventsReceiver(cb: observer)
    }
}

// MARK: - SDK error mapping

private extension PairingModeKind {
    init(_ mode: PairingMode) {
        self = switch mode {
        case .LocalInitial: .localInitial
        case .LocalOpen: .localOpen
        case .PasswordOpen: .passwordOpen
        case .PasswordInvite: .passwordInvite
        }
    }
}

private extension PairingFailure {
    init(_ error: Error) {
        switch error {
        case IamError.USERNAME_EXISTS: self = .usernameExists
        case IamError.AUTHENTICATION_ERROR: self = .authenticationFailed
        case IamError.BLOCKED_BY_DEVICE_CONFIGURATION: self = .blockedByDeviceConfiguration
        case NabtoEdgeClientError.NO_CHANNELS: self = .deviceOffline
        default: self = .other("\(error)")
        }
    }
}

extension DeviceFailure {
    /// Map anything thrown out of ``NabtoClient`` onto the small set of outcomes the UI cares about.
    static func from(_ error: Error) -> DeviceFailure {
        switch error {
        case ThermostatError.deviceIdentityChanged: .identityChanged
        case NabtoEdgeClientError.NO_CHANNELS: .offline
        case NabtoEdgeClientError.TIMEOUT: .timedOut
        case NabtoEdgeClientError.STOPPED: .stopped
        case let NabtoEdgeClientError.FAILED_WITH_DETAIL(detail): .other(detail)
        case let IamError.API_ERROR(cause): from(cause)
        default: .other("\(error)")
        }
    }
}
