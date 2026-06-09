import XCTest
@testable import HKNetworkKit

private enum SampleAPI: EndpointProtocol {
    case scans(page: Int)
    case create

    var baseURL: String { "https://api.example.com/v1" }

    var endpoint: String {
        switch self {
        case .scans(let page): return "/scans?page=\(page)&limit=10"
        case .create:          return "/scans"
        }
    }

    var method: String {
        switch self {
        case .scans:  return "GET"
        case .create: return "POST"
        }
    }

    var headers: [String: String] { ["X-Test": "1"] }
}

final class EndpointProtocolTests: XCTestCase {

    private func makeClient(_ session: MockURLSession) -> NetworkClient {
        let config = NetworkConfiguration(
            baseURL: URL(string: "https://fallback.example.com")!,
            retryPolicy: NoRetryPolicy(),
            logger: ConsoleLogger(level: .none)
        )
        return NetworkClient(configuration: config, session: session)
    }

    func testBridgesURLMethodHeadersAndSplitsQuery() async throws {
        let session = MockURLSession()
        session.enqueue(.init(data: Data(#"{"id":1,"name":"Ada"}"#.utf8)))
        let client = makeClient(session)

        let user = try await client.send(SampleAPI.scans(page: 2), as: User.self)
        XCTAssertEqual(user.value, User(id: 1, name: "Ada"))

        let request = try XCTUnwrap(session.recordedRequests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Test"), "1")

        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
        XCTAssertEqual(components?.path, "/v1/scans")                       // baseURL path preserved
        XCTAssertEqual(components?.queryItems?.count, 2)                    // query split out
        XCTAssertTrue(components?.queryItems?.contains(URLQueryItem(name: "page", value: "2")) ?? false)
    }

    func testPostWithBody() async throws {
        let session = MockURLSession()
        session.enqueue(.init(data: Data(#"{"id":2,"name":"Grace"}"#.utf8), statusCode: 201))
        let client = makeClient(session)

        let body = Data(#"{"name":"Grace"}"#.utf8)
        let response = try await client.send(SampleAPI.create, body: body, as: User.self)

        XCTAssertEqual(response.value.name, "Grace")
        XCTAssertEqual(session.recordedRequests.first?.httpMethod, "POST")
        XCTAssertEqual(session.recordedRequests.first?.httpBody, body)
    }
}
