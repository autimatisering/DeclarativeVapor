//import XCTest
//import Vapor
//import MongoKitten
//import Meow
//import DeclarativeAPI
//
//struct User: MeowModel {
//    var _id: String
//    let name: String
//}
//
//struct UserKey: PathKey {
//    typealias Value = User.Identifier
//}
//
//struct GetUser: DeclarativeAPI.DeclarativeResponder {
//    @RouteParameter<UserKey> var userId
//    @AppEnvironment(\.meow) var db
//    
//    var route: some RouteProtocol {
//        GET("users", $userId)
//    }
//    
//    func respond(to request: RouteRequest<GetUser>) throws -> some RouteResponse {
//        return User(_id: request.userId, name: "Hoi")
//            .saving(to: request.db)
//    }
//}
//
//final class DeclarativeAPITests: XCTestCase {
//    let app = Application()
//    
//    func testExample() throws {
//        let request = Vapor.Request(application: app, method: .GET, url: "/users/1", on: app.eventLoopGroup.next())
//        
//        let response = try GetUser().respond(to: request).wait()
//        print(response)
//    }
//
//    static var allTests = [
//        ("testExample", testExample),
//    ]
//}
//
//extension ApplicationValues {
//    fileprivate struct MongoStorageKey: StorageKey {
//        typealias Value = MongoDatabase
//    }
//    
//    var database: MongoDatabase {
//        if let db = app.storage[MongoStorageKey.self] {
//            return db
//        }
//        
//        let db = try! MongoDatabase.synchronousConnect("mongodb://localhost/decl")
//        app.storage[MongoStorageKey.self] = db
//        return db
//    }
//    
//    var meow: MeowDatabase {
//        MeowDatabase(database)
//    }
//}
//
//public protocol MeowModel: Meow.Model, RouteResponse, Content {}
//
//extension MeowModel {
//    public func saving(to db: MeowDatabase) -> some RouteResponse {
//        DelayedResponse(self, untilSuccess: save(in: db))
//    }
//}
