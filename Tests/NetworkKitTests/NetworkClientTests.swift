import XCTest
@testable import NetworkKit

final class NetworkClientTests: XCTestCase {
    let baseURL = URL(string: "https://api.example.com")!

    private func makeClient(
        session: MockURLSession,
        auth: AuthenticationProvider? = nil,
        retry: RetryPolicy = NoRetryPolicy()
    ) -> NetworkClient {
        let config = NetworkConfiguration(
            baseURL: baseURL,
            retryPolicy: retry,
            logger: ConsoleLogger(level: .none),
            authenticationProvider: auth
        )
        return NetworkClient(configuration: config, session: session)
    }

    func testGetDecodesResponse() async throws {
        let session = MockURLSession()
        session.enqueue(.init(data: Data(#"{"id":1,"name":"Ada"}"#.utf8)))
        let client = makeClient(session: session)

        let response = try await client.send(TestAPI.GetUser(id: 1), as: User.self)

        XCTAssertEqual(response.value, User(id: 1, name: "Ada"))
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(session.recordedRequests.first?.url?.absoluteString, "https://api.example.com/users/1")
        XCTAssertEqual(session.recordedRequests.first?.httpMethod, "GET")
    }

    func testPostEncodesJSONBody() async throws {
        let session = MockURLSession()
        session.enqueue(.init(data: Data(#"{"id":2,"name":"Grace"}"#.utf8), statusCode: 201))
        let client = makeClient(session: session)

        let response = try await client.send(TestAPI.CreateUser(name: "Grace"), as: User.self)

        XCTAssertEqual(response.value.name, "Grace")
        let body = try XCTUnwrap(session.recordedRequests.first?.httpBody)
        XCTAssertEqual(try JSONDecoder().decode(CreateUserRequest.self, from: body).name, "Grace")
        XCTAssertEqual(session.recordedRequests.first?.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testUnauthorizedThrows() async {
        let session = MockURLSession()
        session.enqueue(.init(statusCode: 401))
        let client = makeClient(session: session)

        do {
            _ = try await client.send(TestAPI.GetUser(id: 1), as: User.self)
            XCTFail("Expected unauthorized error")
        } catch let error as APIError {
            guard case .unauthorized = error else {
                return XCTFail("Expected .unauthorized, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testDecodingErrorIsWrapped() async {
        let session = MockURLSession()
        session.enqueue(.init(data: Data("not json".utf8)))
        let client = makeClient(session: session)

        do {
            _ = try await client.send(TestAPI.GetUser(id: 1), as: User.self)
            XCTFail("Expected decoding error")
        } catch let error as APIError {
            guard case .decoding = error else {
                return XCTFail("Expected .decoding, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testRetryThenSucceeds() async throws {
        let session = MockURLSession()
        session.enqueue(.init(statusCode: 503))                                   // first attempt fails
        session.enqueue(.init(data: Data(#"{"id":1,"name":"Ada"}"#.utf8)))        // retry succeeds
        let retry = DefaultRetryPolicy(maxRetryCount: 1, strategy: .fixed(0.01))
        let client = makeClient(session: session, retry: retry)

        let response = try await client.send(TestAPI.GetUser(id: 1), as: User.self)

        XCTAssertEqual(response.value, User(id: 1, name: "Ada"))
        XCTAssertEqual(session.recordedRequests.count, 2)
    }

    func testTokenRefreshOn401ThenRetries() async throws {
        let session = MockURLSession()
        session.enqueue(.init(statusCode: 401))                                   // initial: unauthorized
        session.enqueue(.init(data: Data(#"{"id":9,"name":"Refreshed"}"#.utf8)))  // after refresh
        let provider = BearerTokenProvider(token: "stale") { "fresh-token" }
        let client = makeClient(session: session, auth: provider)

        let response = try await client.send(TestAPI.Secure(), as: User.self)

        XCTAssertEqual(response.value.name, "Refreshed")
        XCTAssertEqual(session.recordedRequests.count, 2)
        XCTAssertEqual(session.recordedRequests.last?.value(forHTTPHeaderField: "Authorization"), "Bearer fresh-token")
    }

    func testEnforcesHTTPS() async {
        let session = MockURLSession()
        let config = NetworkConfiguration(
            baseURL: URL(string: "http://insecure.example.com")!,
            logger: ConsoleLogger(level: .none),
            enforcesHTTPS: true
        )
        let client = NetworkClient(configuration: config, session: session)

        do {
            _ = try await client.send(TestAPI.GetUser(id: 1), as: User.self)
            XCTFail("Expected SSL error")
        } catch let error as APIError {
            guard case .ssl = error else {
                return XCTFail("Expected .ssl, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMultipartUpload() async throws {
        let session = MockURLSession()
        session.enqueue(.init(data: Data(#"{"id":3,"name":"Img"}"#.utf8)))
        let client = makeClient(session: session)

        var form = MultipartFormData()
        form.append(Data([0xFF, 0xD8, 0xFF]), name: "avatar", fileName: "a.jpg", mimeType: "image/jpeg")
        struct UploadEndpoint: Endpoint {
            let body: RequestBody
            var path: String { "/upload" }
            var method: HTTPMethod { .post }
            var requiresAuthentication: Bool { false }
        }

        let response = try await client.upload(UploadEndpoint(body: .multipart(form)), as: User.self)

        XCTAssertEqual(response.value.id, 3)
        let contentType = session.recordedRequests.first?.value(forHTTPHeaderField: "Content-Type")
        XCTAssertEqual(contentType?.hasPrefix("multipart/form-data; boundary="), true)
    }
}
