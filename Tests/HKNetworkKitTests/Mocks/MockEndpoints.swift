import Foundation
import HKNetworkKit

struct User: Codable, Equatable, Sendable {
    let id: Int
    let name: String
}

struct CreateUserRequest: Codable, Sendable {
    let name: String
}

enum TestAPI {
    struct GetUser: Endpoint {
        let id: Int
        var path: String { "/users/\(id)" }
        var requiresAuthentication: Bool { false }
    }

    struct CreateUser: Endpoint {
        let body: RequestBody
        var path: String { "/users" }
        var method: HTTPMethod { .post }
        var requiresAuthentication: Bool { false }

        init(name: String) {
            self.body = .json(CreateUserRequest(name: name))
        }
    }

    struct Secure: Endpoint {
        var path: String { "/me" }
        var requiresAuthentication: Bool { true }
    }
}
