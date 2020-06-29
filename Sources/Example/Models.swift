import NIO
import BSON
import DeclarativeAPI
import JWTKit
import Fluent

enum AccountType: String, Codable, Comparable {
    static func < (lhs: AccountType, rhs: AccountType) -> Bool {
        if lhs == .user && rhs == .admin {
            return true
        } else {
            return false
        }
    }
    
    case admin, user
}

final class User: UserModel {
    typealias E = User
    func encode(for request: Request) -> EventLoopFuture<User> {
        request.eventLoop.future(self)
    }
    
    static let jwtSigner = JWTSigner.hs512(key: "TEST".data(using: .utf8)!)
    static var tokenLifetime = TimeAmount.hours(1)
    static var passwordKeyPath: KeyPath<User, Field<PasswordHash>> { \.$password }
    static var tokenType = UserTokenType.header("X-API-Token")
    
    static let schema = "users"
    
    @ID(custom: .id) var id: ObjectId?
    @Group(key: "profile") var profile: UserProfile
    @Field(key: "password") var password: PasswordHash
    
    init(named name: String, password: PasswordHash) {
        self.profile = UserProfile(named: name)
        self.password = password
    }
    
    init() {}
}

public final class UserProfile: Fields, RouteContent {
    public typealias E = UserProfile
    
    @Field(key: "name") var name: String
    @Field(key: "type") var type: AccountType
    
    init(named name: String) {
        self.name = name
        self.type = .user
    }
    
    public init() { }
}

extension JWTSigner {
    static let api = JWTSigner.hs512(key: "example".data(using: .utf8)!)
}

enum TokenError: Error {
    case missingHeader
}
