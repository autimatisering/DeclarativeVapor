import DeclarativeAPI
import FluentKit
import Fluent
import Vapor

extension Model {
    public func saving(to db: Database) -> DelayedResult<Self> {
        DelayedResult(self, untilSuccess: save(on: db))
    }
}

struct AllResults<M: Model>: RouteResponse {
    typealias E = [M]
    private let database: Database
    private var failable = false

    init(of type: M.Type, in database: Database) {
        self.database = database
    }
    
    func encode(for request: Request) -> EventLoopFuture<[M]> {
        database.query(M.self).all()
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
