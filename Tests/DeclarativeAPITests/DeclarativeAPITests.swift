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

struct UserId: PathKey {
    typealias Value = User.Identifier
}



//struct GetUser: Responder {
//    
//}

final class DeclarativeAPITests: XCTestCase {
    func testExample() throws {
        let route = GET<User>("users", UserId()) { request in
            let id = try request.parameter(UserId.self)
            
            return .ok(User(id: id, name: "Joannis"))
        }
        
        print(
            try route.execute(
                HTTPRequest(
                    method: "GET",
                    components: ["users", "1"],
                    body: []
                )
            )
        )
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
