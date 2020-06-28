import NIO
import Vapor
import Fluent
import JWTKit

public protocol UserModel: Model, AsynchronousEncodable {
    static var passwordKeyPath: KeyPath<Self, Field<PasswordHash>> { get }
    static var tokenType: UserTokenType { get }
    static var tokenLifetime: TimeAmount { get }
    static var jwtSigner: JWTSigner { get }
}

public enum UserTokenType {
    case header(String)
}

fileprivate struct _UserToken<User: UserModel>: JWTPayload {
    func verify(using signer: JWTSigner) throws {
        try exp.verifyNotExpired()
    }
    
    let exp: ExpirationClaim
    let user: User.IDValue
}

public struct UserToken<User: UserModel>: RouteContent {
    public typealias E = Self
    
    fileprivate let wrapped: _UserToken<User>
    
    fileprivate init(wrapped: _UserToken<User>) {
        self.wrapped = wrapped
    }
    
    public func resolveUser(in database: Fluent.Database) -> Asynchronous<User> {
        let user = User.find(wrapped.user, on: database)
            .unwrap(or: Abort(.notFound))
        
        return Asynchronous(user)
    }
    
    public func encode(to encoder: Encoder) throws {
        let token = try User.jwtSigner.sign(wrapped)
        try token.encode(to: encoder)
    }
    
    public init(from decoder: Decoder) throws {
        let token = try String(from: decoder)
        wrapped = try User.jwtSigner.verify(token)
    }
}

public struct TokenValue<User: UserModel>: RequestValue {
    public typealias Value = UserToken<User>
    
    public static func makeValue(from request: Vapor.Request) throws -> UserToken<User> {
        let token: String
        
        switch User.tokenType {
        case .header(let header):
            guard let _token = request.headers.first(name: header) else {
                throw DeclarativeAPIError.missingHeader(header)
            }
            
            token = _token
        }
        
        return UserToken(wrapped: try User.jwtSigner.verify(token))
    }
}

public struct ResolvedTokenValue<User: UserModel>: AsynchronousRequestValue {
    public typealias Value = User
    
    public static func makeValue(from request: Request) -> EventLoopFuture<User> {
        do {
            let token = try TokenValue<User>.makeValue(from: request)
            return token.resolveUser(in: request.db).result
        } catch {
            return request.eventLoop.future(error: error)
        }
    }
}

public typealias RequestToken<User: UserModel> = RequestEnvironment<TokenValue<User>>

public typealias Authenticated<User: UserModel> = AsynchronousRequestEnvironment<ResolvedTokenValue<User>>

extension RequestEnvironment {
    public init<User: UserModel>(_ type: User.Type) where Key == TokenValue<User> {
        self.init(TokenValue<User>.self)
    }
}

extension AsynchronousRequestEnvironment {
    public init<User: UserModel>(as type: User.Type) where Key == ResolvedTokenValue<User> {
        self.init(ResolvedTokenValue<User>.self)
    }
}

extension UserModel {
    public typealias Token = UserToken<Self>
    
    public func token() throws -> Token {
        guard let id = self.id else {
            throw DeclarativeAPIError.cannotCreateToken(.missingUserIdentifier)
        }
        
        let expiration = Self.tokenLifetime.nanoseconds / TimeAmount.seconds(1).nanoseconds
        
        return Token(
            wrapped: _UserToken(
                exp: ExpirationClaim(
                    value: Date().addingTimeInterval(Double(expiration))
                ),
                user: id
            )
        )
    }
}

enum JWTTokenErrorReason {
    case missingUserIdentifier
}

enum DeclarativeAPIError: Error {
    case missingHeader(String)
    case cannotCreateToken(JWTTokenErrorReason)
}

extension _AsynchronousResult {
    public func token<User: UserModel>() -> Asynchronous<User.Token> where Result == User {
        Asynchronous(self.result.flatMapThrowing { try $0.token() })
    }
    
    public func flatten<R>() -> Asynchronous<R> where Self.Result: _AsynchronousResult, Result.Result == R {
        Asynchronous<R>(result.flatMap(\.result))
    }
}
