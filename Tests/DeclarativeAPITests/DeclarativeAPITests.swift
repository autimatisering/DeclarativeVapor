import XCTest
import DeclarativeAPI

protocol Model: Codable {
    associatedtype Identifier: Hashable
}

struct User: Model {
    typealias Identifier = String
    
    let id: Identifier
    let name: String
}

struct UserKey: PathKey {
    typealias Value = User.Identifier
}

struct GetUser: Responder {
    @RouteParameter<UserKey> var userId
    
    var route: GET<User> {
        GET<User>("users", $userId) { request in
            return User(id: request.userId, name: "Hoi")
        }
    }
}

final class DeclarativeAPITests: XCTestCase {
    func testExample() throws {
        print(try GetUser().respond(to: HTTPRequest(
            method: "GET",
            path: ["users", "1"],
            body: []
        )))
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
