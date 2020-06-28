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
            JSONKey("token") {
                user.token()
            }
            
            JSONKey("profile") {
                user.profile
            }
        }
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
