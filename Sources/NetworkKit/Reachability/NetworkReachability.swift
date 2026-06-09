import Foundation
import Network

/// A lightweight network reachability monitor built on Apple's `Network`
/// framework — a dependency-free, modern replacement for `Reachability.swift`.
///
/// Designed to be effortless to use:
///
/// ```swift
/// // 1. Shared singleton, already monitoring:
/// if NetworkReachability.shared.isConnected { /* ... */ }
///
/// // 2. Closure callback:
/// NetworkReachability.shared.onChange = { connection in
///     print("Now on \(connection)")
/// }
///
/// // 3. async/await stream:
/// for await connection in NetworkReachability.shared.changes {
///     print(connection.isOnline ? "online" : "offline")
/// }
///
/// // 4. Suspend until connectivity returns:
/// await NetworkReachability.shared.waitUntilConnected()
/// ```
public final class NetworkReachability: @unchecked Sendable {

    /// The kind of active network connection.
    public enum Connection: Sendable, CustomStringConvertible {
        case wifi
        case cellular
        case ethernet
        case other
        case unavailable

        /// Whether any usable connection is present.
        public var isOnline: Bool { self != .unavailable }

        public var description: String {
            switch self {
            case .wifi: return "WiFi"
            case .cellular: return "Cellular"
            case .ethernet: return "Ethernet"
            case .other: return "Other"
            case .unavailable: return "Unavailable"
            }
        }
    }

    /// A shared monitor that begins observing on first access.
    public static let shared: NetworkReachability = {
        let reachability = NetworkReachability()
        reachability.start()
        return reachability
    }()

    private let monitor: NWPathMonitor
    private let queue: DispatchQueue
    private let lock = NSLock()

    private var _connection: Connection = .unavailable
    private var _isExpensive = false
    private var _isConstrained = false
    private var _isStarted = false
    private var _onChange: (@Sendable (Connection) -> Void)?
    private var continuations: [UUID: AsyncStream<Connection>.Continuation] = [:]

    /// Creates a monitor. Pass an interface type to monitor only that interface.
    public init(requiredInterfaceType: NWInterface.InterfaceType? = nil) {
        if let type = requiredInterfaceType {
            monitor = NWPathMonitor(requiredInterfaceType: type)
        } else {
            monitor = NWPathMonitor()
        }
        queue = DispatchQueue(label: "NetworkKit.Reachability")
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Current state (thread-safe snapshots)

    /// The current connection type.
    public var connection: Connection {
        lock.lock(); defer { lock.unlock() }
        return _connection
    }

    /// Whether the device currently has a usable connection.
    public var isConnected: Bool { connection.isOnline }

    /// Whether the active path is considered expensive (e.g. cellular, hotspot).
    public var isExpensive: Bool {
        lock.lock(); defer { lock.unlock() }
        return _isExpensive
    }

    /// Whether the active path is in Low Data Mode.
    public var isConstrained: Bool {
        lock.lock(); defer { lock.unlock() }
        return _isConstrained
    }

    // MARK: - Callbacks

    /// A closure invoked on every connectivity change. Called on a background
    /// queue — dispatch to the main actor before touching UI.
    public var onChange: (@Sendable (Connection) -> Void)? {
        get {
            lock.lock(); defer { lock.unlock() }
            return _onChange
        }
        set {
            lock.lock(); defer { lock.unlock() }
            _onChange = newValue
        }
    }

    /// An async stream of connectivity changes. Each access returns an
    /// independent stream; iterate it in a `for await` loop.
    public var changes: AsyncStream<Connection> {
        AsyncStream { continuation in
            let id = UUID()
            lock.lock()
            continuations[id] = continuation
            let current = _connection
            lock.unlock()

            continuation.yield(current)
            continuation.onTermination = { [weak self] _ in
                self?.removeContinuation(id)
            }
        }
    }

    // MARK: - Lifecycle

    /// Begins monitoring. Idempotent — safe to call multiple times.
    public func start() {
        lock.lock()
        guard !_isStarted else { lock.unlock(); return }
        _isStarted = true
        lock.unlock()

        monitor.pathUpdateHandler = { [weak self] path in
            self?.handle(path)
        }
        monitor.start(queue: queue)
    }

    /// Stops monitoring and finishes all async streams.
    public func stop() {
        monitor.cancel()
        lock.lock()
        _isStarted = false
        let continuations = self.continuations.values
        self.continuations.removeAll()
        lock.unlock()
        continuations.forEach { $0.finish() }
    }

    /// Suspends until the device is connected. Returns immediately if already on.
    public func waitUntilConnected() async {
        for await connection in changes where connection.isOnline {
            return
        }
    }

    // MARK: - Internals

    private func handle(_ path: NWPath) {
        let connection = Self.connection(for: path)

        lock.lock()
        _connection = connection
        _isExpensive = path.isExpensive
        _isConstrained = path.isConstrained
        let callback = _onChange
        let continuations = Array(self.continuations.values)
        lock.unlock()

        callback?(connection)
        continuations.forEach { $0.yield(connection) }
    }

    private func removeContinuation(_ id: UUID) {
        lock.lock(); defer { lock.unlock() }
        continuations[id] = nil
    }

    private static func connection(for path: NWPath) -> Connection {
        guard path.status == .satisfied else { return .unavailable }
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .ethernet }
        return .other
    }
}
