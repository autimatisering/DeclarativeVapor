import Fluent
import BSON
import DeclarativeAPI

struct CreateUser: PostResponder {
    @RequestEnvironment(FluentDatabase.self) var db
    
    struct Input: Decodable {
        let name: String
        let password: String
    }
    
    func makeRoute() -> PostRoute {
        PostRoute("register")
    }
    
    func respond(
        to request: RouteRequest<CreateUser>
    ) throws -> some RouteResponse {
        let user = HashPassword(request.body.password) { hash in
            User(named: request.body.name, password: hash)
                .saving(to: request.db)
        }.flatten(on: request)
        
        return JSONObject {
            JSONKey("token", value: user.token())
            JSONKey("profile", value: user.profile)
        }
    }
}

struct GetProfile: GetResponder {
    @RequestEnvironment(FluentDatabase.self) var db
    @Authenticated(as: User.self) var user
    
    func makeRoute() -> GetRoute {
        GetRoute("users", "me")
    }
    
    func respond(to request: RouteRequest<GetProfile>) throws -> some RouteResponse {
        request.user.profile
    }
}

struct SneakyPromoteAdmin: GetResponder {
    @RequestEnvironment(FluentDatabase.self) var db
    @Authenticated(as: User.self) var user
    
    func makeRoute() -> GetRoute {
        GetRoute("users", "me", "become-admin")
    }
    
    func respond(to request: RouteRequest<SneakyPromoteAdmin>) throws -> some RouteResponse {
        request.user.profile.type = .admin
        
        return request.user
            .saving(to: request.db)
            .profile
    }
}

struct ListAll<M: Model>: GetResponder {
    @RequestEnvironment(FluentDatabase.self) var db
    @RequestToken(User.self) var token
    
    func makeRoute() -> GetRoute {
        GetRoute(M.schema)
    }
    
    func respond(to request: RouteRequest<Self>) throws -> some RouteResponse {
        AllResults(of: M.self, in: request.db)
            .failable()
    }
}

struct PermissionsCheck: InboundMiddleware {
    let type: AccountType
    @Authenticated(as: User.self) var user
    
    init(type: AccountType) {
        self.type = type
    }
    
    func handleRequest(_ request: MiddlewareRequest<Self>) throws {
        guard request.user.profile.type >= type else {
            throw Abort(.unauthorized)
        }
    }
}
