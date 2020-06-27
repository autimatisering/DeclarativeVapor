import DeclarativeAPI
import JWTKit
import BSON

struct User: MeowModel {
    static let collectionName = "users"
    
    var _id: ObjectId
    let name: String
}

struct Token: JWTPayload, RequestValue {
    typealias Value = Self
    
    func verify(using signer: JWTSigner) throws {
        try exp.verifyNotExpired()
    }
    
    let exp: ExpirationClaim
    let user: User.Identifier
    
    init(user: User.Identifier) {
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
