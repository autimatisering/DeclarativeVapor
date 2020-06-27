import XCTest
import Vapor
import MongoKitten
import Meow
import DeclarativeAPI

struct User: Model {
    var _id: String
    let name: String
}

struct UserKey: PathKey {
    typealias Value = User.Identifier
}

struct GetUser: DeclarativeAPI.Responder {
    @RouteParameter<UserKey> var userId
    @AppEnvironment(\.meow) var db
    
    var route: GET<User> {
        GET<User>("users", $userId) { request in
            return User(_id: request.userId, name: "Hoi")
                .saved(in: request.db)
        }
    }
}

final class DeclarativeAPITests: XCTestCase {
    let app = Application()
    
    func testExample() throws {
        let request = Vapor.Request(application: app, method: .GET, url: "/users/1", on: app.eventLoopGroup.next())
        
        let response = try GetUser().respond(to: request)
        XCTAssertEqual(response.body._id, "1")
        XCTAssertEqual(response.body.name, "Hoi")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}

extension ApplicationValues {
    fileprivate struct MongoStorageKey: StorageKey {
        typealias Value = MongoDatabase
    }
    
    var database: MongoDatabase {
        if let db = app.storage[MongoStorageKey.self] {
            return db
        }
        
        let db = try! MongoDatabase.synchronousConnect("mongodb://localhost/decl")
        app.storage[MongoStorageKey.self] = db
        return db
    }
    
    var meow: MeowDatabase {
        MeowDatabase(database)
    }
}

extension Model {
    public func saved(in db: MeowDatabase) -> Self {
        print(db)
        return self
//        DelayedResponse(self, untilSuccess: save(in: db))
    }
}
