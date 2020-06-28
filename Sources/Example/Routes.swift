import Fluent
import BSON
import DeclarativeAPI

struct CreateUser: PostResponder {
    @RequestEnvironment(FluentDatabase.self) var db
    
    struct Input: Decodable {
        let name: String
    }
    
    func makeRoute() -> PostRoute {
        PostRoute(User.schema)
    }
    
    func respond(to request: RouteRequest<CreateUser>) throws -> some RouteResponse {
        return User(named: request.body.name)
            .saving(to: request.db)
    }
}

struct ListAll<M: Model>: GetResponder {
    @RequestEnvironment(FluentDatabase.self) var db
//    @RequestEnvironment(Token.self) var token
    
    func makeRoute() -> GetRoute {
        GetRoute(M.schema)
    }
    
    func respond(to request: RouteRequest<Self>) throws -> some RouteResponse {
        AllResults(of: M.self, in: request.db)
            .failable()
    }
}
