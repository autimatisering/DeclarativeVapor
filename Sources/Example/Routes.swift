import BSON
import DeclarativeAPI

struct CreateUser: PostResponder {
    @AppEnvironment(\.meow) var db
    
    struct Input: Decodable {
        let name: String
    }
    
    func makeRoute() -> PostRoute {
        PostRoute(User.collectionName)
    }
    
    func respond(to request: RouteRequest<CreateUser>) throws -> some RouteResponse {
        return User(_id: ObjectId(), name: request.body.name)
            .saving(to: request.db)
    }
}

struct ListAll<M: MeowModel>: GetResponder {
    @AppEnvironment(\.meow) var db
    @RequestEnvironment(Token.self) var token
    
    func makeRoute() -> GetRoute {
        GetRoute(M.collectionName)
    }
    
    func respond(to request: RouteRequest<Self>) throws -> some RouteResponse {
        AllResults(in: request.db[M.self])
    }
}


//struct GetUser: GetResponder {
//    @RouteParameter<User.Parameter> var userId
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
