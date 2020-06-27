import Foundation

typealias HTTPBody = [UInt8]

protocol HTTPMethod {
    associatedtype InputBody
    
    static var methodName: String { get }
    static func makeBody(from body: HTTPBody) throws -> InputBody
}

enum HTTPMethods {
    struct GET: HTTPMethod {
        typealias InputBody = Void
        
        static let methodName = "GET"
        
        static func makeBody(from body: HTTPBody) throws -> Void {
            guard body.isEmpty else {
                throw CustomRouterError.unexpectedBodyProvided
            }
            
            return ()
        }
    }

    struct POST<InputBody: Decodable>: HTTPMethod {
        static var methodName: String { "POST" }
        
        static func makeBody(from body: HTTPBody) throws -> InputBody {
            try JSONDecoder().decode(InputBody.self, from: Data(body))
        }
    }
}

protocol Middleware {
    associatedtype Input
    associatedtype Output
    
    static func transformInput(_ input: Input) -> Output
}

struct PathComponent {
    fileprivate enum _Component {
        case exact(String)
        case value(ObjectIdentifier)
    }
    
    fileprivate let component: _Component
    
    fileprivate init(component: _Component) {
        self.component = component
    }
}

protocol PathComponentRepresentable {
    var pathComponent: PathComponent { get }
}

extension String: PathComponentRepresentable {
    var pathComponent: PathComponent {
        PathComponent(component: .exact(self))
    }
}

protocol PathKey: PathComponentRepresentable {
    associatedtype Value: LosslessStringConvertible
}

extension PathKey {
    var pathComponent: PathComponent {
        PathComponent(component: .value(ObjectIdentifier(Self.self)))
    }
}

struct Route<Method: HTTPMethod, OutputBody: Encodable> {
    typealias Handler = (Request) throws -> Response
    let components: [PathComponent]
    let handler: Handler
    
    init(
        _ components: PathComponentRepresentable...,
        handler: @escaping Handler
    ) {
        self.components = components.map(\.pathComponent)
        self.handler = handler
    }
}

typealias GET<OutputBody: Encodable> = Route<HTTPMethods.GET, OutputBody>

struct RouteGroup {
    
}

enum CustomRouterError: Error {
    case pathComponentDecodeFailure(input: String, output: Any.Type)
    case invalidHttpMethod(provided: String, needed: String)
    case unexpectedBodyProvided
}

extension Route {
    struct Request {
        let routerComponents: [PathComponent]
        let requestComponents: [String]
        let body: Method.InputBody
        
        func parameter<Key: PathKey>(_ type: Key.Type) throws -> Key.Value {
            let component = ""
            guard let value = Key.Value(component) else {
                throw CustomRouterError.pathComponentDecodeFailure(
                    input: "",
                    output: Key.Value.self
                )
            }
            
            return value
        }
    }
    
    struct Response {
        let code: Int
        let body: OutputBody
        
        static func ok(_ body: OutputBody) -> Response {
            Response(code: 200, body: body)
        }
    }
    
    func execute(_ request: HTTPRequest) throws -> Response {
        guard
            request.method == Method.methodName,
            request.components.count == self.components.count
        else {
            throw CustomRouterError.invalidHttpMethod(
                provided: request.method,
                needed: Method.methodName
            )
        }
        
        let request = Request(
            routerComponents: self.components,
            requestComponents: request.components,
            body: try Method.makeBody(from: request.body)
        )
        
        return try self.handler(request)
    }
}

struct HTTPRequest {
    let method: String
    let components: [String]
    let body: HTTPBody
}
