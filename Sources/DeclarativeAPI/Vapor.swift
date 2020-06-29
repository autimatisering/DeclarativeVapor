public struct AsyncPasswordHasherKey: RequestValue {
    public typealias Value = AsyncPasswordHasher
    
    public static func makeValue(from request: Vapor.Request) throws -> AsyncPasswordHasher {
        request.password.async
    }
}

public struct HashPassword<R: AsynchronousEncodable>: RouteResponse {
    public typealias E = R.E
    
    private let password: String
    private let onHash: (PasswordHash) throws -> R
    
    public init(_ password: String, onHash: @escaping (PasswordHash) -> R) {
        self.password = password
        self.onHash = onHash
    }
    
    public func encode(for request: Request) -> EventLoopFuture<R.E> {
        request.password.async.hash(password)
            .map(PasswordHash.init)
            .flatMapThrowing(onHash)
            .flatMap { $0.encode(for: request) }
    }
    
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        encode(for: request).flatMapThrowing { encodable in
            let response = Response()
            try response.content.encode(encodable, as: .json)
            return response
        }
    }
}

public struct PasswordHash: Codable {
    private let hash: String
    
    internal init(hash: String) {
        self.hash = hash
    }
    
    public func encode(to encoder: Encoder) throws {
        try hash.encode(to: encoder)
    }
    
    public init(from decoder: Decoder) throws {
        self.hash = try String(from: decoder)
    }
}
