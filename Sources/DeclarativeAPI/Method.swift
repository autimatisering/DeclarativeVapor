import Vapor

public protocol HTTPMethod {
    associatedtype InputBody
    
    static var method: Vapor.HTTPMethod { get }
    static func makeBody(from body: HTTPBody) throws -> InputBody
}

public enum HTTPMethods {
    public struct GET: HTTPMethod {
        public typealias InputBody = Void
        
        public static let method = Vapor.HTTPMethod.GET
        
        public static func makeBody(from body: HTTPBody) throws -> Void {}
    }

    public struct POST<InputBody: Decodable>: HTTPMethod {
        public static var method: Vapor.HTTPMethod { .POST }
        
        public static func makeBody(from body: HTTPBody) throws -> InputBody {
            guard let buffer = body.data else {
                throw CustomRouterError.missingBody
            }
            
            return try JSONDecoder().decode(InputBody.self, from: buffer)
        }
    }
}
