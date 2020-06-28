import FluentKit
import Fluent
import Vapor

extension Model {
    public func saving(to db: Database) -> DelayedResult<Self> {
        DelayedResult(self, untilSuccess: save(on: db))
    }
}

public struct AllResults<M: Model>: RouteResponse {
    public typealias E = [M]
    private let database: Database
    private var failable = false

    public init(of type: M.Type, in database: Database) {
        self.database = database
    }
    
    public func encode(for request: Request) -> EventLoopFuture<[M]> {
        database.query(M.self).all()
    }

    public func failable(failable: Bool = true) -> Self {
        var copy = self
        copy.failable = true
        return copy
    }
}

public struct FluentDatabase: RequestValue {
    public typealias Value = Fluent.Database
    
    public static func makeValue(from request: Vapor.Request) throws -> Database {
        request.db
    }
}
