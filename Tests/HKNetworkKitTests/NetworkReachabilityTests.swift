import XCTest
@testable import HKNetworkKit

final class NetworkReachabilityTests: XCTestCase {

    func testConnectionIsOnlineFlag() {
        XCTAssertTrue(NetworkReachability.Connection.wifi.isOnline)
        XCTAssertTrue(NetworkReachability.Connection.cellular.isOnline)
        XCTAssertTrue(NetworkReachability.Connection.ethernet.isOnline)
        XCTAssertFalse(NetworkReachability.Connection.unavailable.isOnline)
    }

    func testUnstartedMonitorReportsUnavailable() {
        let reachability = NetworkReachability()
        XCTAssertFalse(reachability.isConnected)
        XCTAssertEqual(reachability.connection, .unavailable)
    }

    func testClientFailsFastWhenUnreachable() async {
        let session = MockURLSession()
        session.enqueue(.init(data: Data(#"{"id":1,"name":"Ada"}"#.utf8)))
        // A monitor that was never started reports `.unavailable`.
        let config = NetworkConfiguration(
            baseURL: URL(string: "https://api.example.com")!,
            logger: ConsoleLogger(level: .none),
            reachability: NetworkReachability(),
            failsWhenUnreachable: true
        )
        let client = NetworkClient(configuration: config, session: session)

        do {
            _ = try await client.send(TestAPI.GetUser(id: 1), as: User.self)
            XCTFail("Expected network error while offline")
        } catch let error as APIError {
            guard case .network = error else {
                return XCTFail("Expected .network, got \(error)")
            }
            // Should fail fast without ever hitting the transport.
            XCTAssertTrue(session.recordedRequests.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testChangesStreamEmitsCurrentValue() async {
        let reachability = NetworkReachability()
        var received: NetworkReachability.Connection?
        for await connection in reachability.changes {
            received = connection
            break
        }
        XCTAssertEqual(received, .unavailable)
    }
}
