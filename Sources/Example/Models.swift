import BSON
import DeclarativeAPI
import JWTKit
import Fluent

final class User: Model, RouteContent {
    static let schema = "users"
    
    @ID(custom: .id) var id: ObjectId?
    @Field(key: "name") var name: String
    
    init(named name: String) {
        self.name = name
    }
    
    init() {}
}

struct Token: JWTPayload, RequestValue {
    typealias Value = Self
    
    func verify(using signer: JWTSigner) throws {
        try exp.verifyNotExpired()
    }
    
    let exp: ExpirationClaim
    let user: User.IDValue
    
    init(user: User.IDValue) {
        self.user = user
        self.exp = ExpirationClaim(value: Date().addingTimeInterval(3600))
    }
    
    static func makeValue(from request: Vapor.Request) throws -> Token {
        guard let token = request.headers.first(name: "X-API-Token") else {
            throw TokenError.missingHeader
        }
        
        return try JWTSigner.api.verify(token)
    }
}

extension JWTSigner {
    static let api = JWTSigner.hs512(key: "example".data(using: .utf8)!)
}

enum TokenError: Error {
    case missingHeader
}
