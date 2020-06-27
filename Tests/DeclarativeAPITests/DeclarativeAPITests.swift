import XCTest
@testable import DeclarativeAPI

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
    
    var route: some Route {
        GET<User>("users", $userId) { request in
            print(request)
            
            return .ok(User(id: request.userId, name: "Hoi"))
        }
    }
}

final class DeclarativeAPITests: XCTestCase {
    func testExample() throws {
//        let route = GET<User>("users", UserId()) { request in
//            let id = try request.parameter(UserId.self)
//            
//            return .ok(User(id: id, name: "Joannis"))
//        }
        
        print(
            try GetUser().respond(to: HTTPRequest(
                method: "GET",
                path: ["users", "1"],
                body: []
            ))
        )
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
