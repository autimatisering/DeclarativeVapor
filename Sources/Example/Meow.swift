//import Meow
//import MongoKitten
//import DeclarativeAPI
//
//fileprivate struct MongoStorageKey: StorageKey {
//    typealias Value = MongoDatabase
//}
//
//extension ApplicationValues {
//    var database: MongoDatabase {
//        app.storage[MongoStorageKey.self]!
//    }
//    
//    var meow: MeowDatabase {
//        MeowDatabase(database)
//    }
//}
//
//extension Application {
//    func connectMongoDB(to uri: String) throws {
//        storage[MongoStorageKey.self] = try .synchronousConnect("mongodb://localhost/decl")
//    }
//}
//
//public protocol MeowModel: Meow.Model, RouteResponse, Content {}
//
//public struct ModelKey<M: MeowModel>: PathKey where M.Identifier: LosslessStringConvertible {
//    public typealias Value = M.Identifier
//}
//
//extension MeowModel where Self.Identifier: LosslessStringConvertible {
//    public typealias Parameter = ModelKey<Self>
//}
//
//extension MeowModel {
//    public func saving(to db: MeowDatabase) -> some RouteResponse {
//        DelayedResponse(self, untilSuccess: save(in: db))
//    }
//}
//
//struct AllResults<M: MeowModel>: RouteResponse {
//    private let collection: MeowCollection<M>
//    private var failable = false
//    
//    init(in collection: MeowCollection<M>) {
//        self.collection = collection
//    }
//    
//    func encodeResponse(
//        for request: Vapor.Request
//    ) -> EventLoopFuture<Vapor.Response> {
//        collection.find()
//            .allResults(failable: failable)
//            .encodeResponse(for: request)
//            .hop(to: request.eventLoop)
//    }
//    
//    func failable(failable: Bool = true) -> Self {
//        var copy = self
//        copy.failable = true
//        return copy
//    }
//}
