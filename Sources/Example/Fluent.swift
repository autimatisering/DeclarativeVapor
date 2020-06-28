import DeclarativeAPI
import FluentKit
import Fluent
import Vapor

extension Model where Self: RouteResponse {
    public func saving(to db: Database) -> some RouteResponse {
        DelayedResponse(self, untilSuccess: save(on: db))
    }
}

struct AllResults<M: Model>: RouteResponse {
    private let database: Database
    private var failable = false

    init(of type: M.Type, in database: Database) {
        self.database = database
    }

    func encodeResponse(
        for request: Vapor.Request
    ) -> EventLoopFuture<Vapor.Response> {
        database.query(M.self).all().flatMapThrowing { models in
            let response = Response(status: .ok)
            try response.content.encode(models, as: .json)
            return response
        }
    }

    func failable(failable: Bool = true) -> Self {
        var copy = self
        copy.failable = true
        return copy
    }
}

struct FluentDatabase: RequestValue {
    typealias Value = Fluent.Database
    
    static func makeValue(from request: Vapor.Request) throws -> Database {
        request.db
    }
}
