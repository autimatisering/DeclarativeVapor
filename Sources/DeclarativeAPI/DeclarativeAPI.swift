import Vapor
import Foundation

public typealias HTTPBody = Vapor.Request.Body

public protocol HTTPMethod {
    associatedtype InputBody
    
    static var methodName: String { get }
    static func makeBody(from body: HTTPBody) throws -> InputBody
}

public enum HTTPMethods {
    public struct GET: HTTPMethod {
        public typealias InputBody = Void
        
        public static let methodName = "GET"
        
        public static func makeBody(from body: HTTPBody) throws -> Void {}
    }

    public struct POST<InputBody: Decodable>: HTTPMethod {
        public static var methodName: String { "POST" }
        
        public static func makeBody(from body: HTTPBody) throws -> InputBody {
            guard let buffer = body.data else {
                throw CustomRouterError.missingBody
            }
            
            return try JSONDecoder().decode(InputBody.self, from: buffer)
        }
    }
}

protocol Middleware {
    associatedtype Input
    associatedtype Output
    
    static func transformInput(_ input: Input) -> Output
}

public struct PathComponent: PathComponentRepresentable {
    fileprivate enum _Component {
        case exact(String)
        case value(ObjectIdentifier)
    }
    
    fileprivate let wrapped: _Component
    
    fileprivate init(component: _Component) {
        self.wrapped = component
    }
    
    public var pathComponent: PathComponent { self }
}

public protocol PathComponentRepresentable {
    var pathComponent: PathComponent { get }
}

extension String: PathComponentRepresentable {
    public var pathComponent: PathComponent {
        PathComponent(component: .exact(self))
    }
}

public protocol SimpleRouteProtocol {
    associatedtype Method: HTTPMethod
    associatedtype OutputBody: Encodable
    
    var components: [PathComponent] { get }
    func respond(to request: Request<Method>) throws -> Response<OutputBody>
}

public struct Route<
    Method: HTTPMethod,
    OutputBody: Encodable
>: DeclarativeAPI.SimpleRouteProtocol {
    public typealias Handler = (Request<Method>) throws -> Response<OutputBody>
    
    public let components: [PathComponent]
    private let handler: Handler
    
    public init(
        _ components: PathComponentRepresentable...,
        handler: @escaping Handler
    ) {
        self.components = components.map(\.pathComponent)
        self.handler = handler
    }
    
    public func respond(to request: Request<Method>) throws -> Response<OutputBody> {
        try handler(request)
    }
}

enum CustomRouterError: Error {
    case pathComponentDecodeFailure(input: String, output: Any.Type)
    case invalidHttpMethod(provided: String, needed: String)
    case unexpectedBodyProvided
    case missingBody
    case missingPathComponent(Any.Type)
}

public struct Request<Method: HTTPMethod> {
    let routerComponents: [PathComponent]
    let requestComponents: [String]
    public let body: Method.InputBody
    
    public func parameter<Key: PathKey>(_ type: Key.Type) throws -> Key.Value {
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

public struct Response<OutputBody: Encodable> {
    let code: Int
    public let body: OutputBody
    
    public static func ok(_ body: OutputBody) -> Self {
        Self(code: 200, body: body)
    }
}

public struct HTTPRequest {
    public let method: String
    public let path: [String]
    public let body: HTTPBody
    
    public init(method: String, path: [String], body: HTTPBody) {
        self.method = method
        self.path = path
        self.body = body
    }
}

protocol RequestContainerBuilder: Encodable {
    func setProperties(in request: RequestContainer) throws
}

public protocol RequestProperty {
    associatedtype PresentedValue
    func presentValue(from container: RequestContainer) -> PresentedValue
}

public final class RequestContainer {
    let requestId: UUID
    let routerComponents: [PathComponent]
    let requestComponents: [String]
    var isActive = true
    fileprivate var storage = [ObjectIdentifier: Any]()
    
    func setValue<Key: RequestContainerKey>(_ value: Key.Value, forKey type: Key.Type) {
        assert(isActive)
        self.storage[ObjectIdentifier(type)] = value
    }
    
    func getValue<Key: RequestContainerKey>(forKey type: Key.Type) -> Key.Value? {
        storage[ObjectIdentifier(type)] as? Key.Value
    }
    
    init(
        application: Application,
        routerComponents: [PathComponent],
        requestComponents: [String]
    ) {
        self.requestId = UUID()
        self.routerComponents = routerComponents
        self.requestComponents = requestComponents
    }
}

extension CodingUserInfoKey {
    static let request = CodingUserInfoKey(rawValue: "delcarative-custom-encodable-request")!
}

extension RequestContainerBuilder {
    public func encode(to encoder: Encoder) throws { }
}

public protocol RequestContainerKey {
    associatedtype Value
}
public protocol PathKey: RequestContainerKey where Value: LosslessStringConvertible {}

//public protocol ApplicationKey: RequestContainerKey {
//    func instantiate(on application: Application)
//}

public struct ApplicationValues {
    public let app: Application
    
    fileprivate init(app: Application) {
        self.app = app
    }
}

fileprivate struct ApplicationValuesKey: RequestContainerKey {
    typealias Value = ApplicationValues
}

@propertyWrapper public struct AppEnvironment<Value>: RequestProperty, RequestContainerBuilder {
    public typealias PresentedValue = Value
    
    let keyPath: KeyPath<ApplicationValues, Value>
    public var wrappedValue: Self { self }
    
    public init(_ keyPath: KeyPath<ApplicationValues, Value>) {
        self.keyPath = keyPath
    }
    
    public func presentValue(from container: RequestContainer) -> PresentedValue {
        guard let appValues = container.getValue(forKey: ApplicationValuesKey.self) else {
            fatalError("_Route parameter is requested before the execution of a request")
        }
        
        return appValues[keyPath: keyPath]
    }
    
    func setProperties(in request: RequestContainer) throws {}
}
    
@propertyWrapper public struct RouteParameter<Key: PathKey>: RequestProperty, RequestContainerBuilder {
    public typealias PresentedValue = Key.Value
    
    public var wrappedValue: Self { self }
    
    public var projectedValue: PathComponent {
        .init(component: .value(ObjectIdentifier(Key.self)))
    }
    
    public init(_ key: Key.Type = Key.self) {}
    
    public func presentValue(from container: RequestContainer) -> PresentedValue {
        guard let value = container.getValue(forKey: Key.self) else {
            fatalError("_Route parameter is requested before the execution of a request")
        }
        
        return value
    }
    
    func setProperties(in request: RequestContainer) throws {
        assert(request.routerComponents.count == request.requestComponents.count)
        
        let keyId = ObjectIdentifier(Key.self)
        
        nextComponent: for i in 0..<request.routerComponents.count {
            let component = request.routerComponents[i]
            guard case let .value(typeId) = component.wrapped, typeId == keyId else {
                continue nextComponent
            }
            
            guard let value = Key.Value(request.requestComponents[i]) else {
                throw CustomRouterError.pathComponentDecodeFailure(
                    input: request.requestComponents[i],
                    output: Key.Value.self
                )
            }
            
            request.storage[keyId] = value
            return
        }
        
        throw CustomRouterError.missingPathComponent(Key.self)
    }
}

public struct ResponderRoute<Method: HTTPMethod>: RouteProtocol {
    public let components: [PathComponent]
    
    public init(
        _ components: PathComponentRepresentable...
    ) {
        self.components = components.map(\.pathComponent)
    }
}

public protocol RouteProtocol {
    associatedtype Method: HTTPMethod
    
    var components: [PathComponent] { get }
}

public protocol RouteResponse: ResponseEncodable {}

public protocol Responder: Encodable {
    associatedtype Route: DeclarativeAPI.RouteProtocol
    associatedtype Response: RouteResponse
    
    var route: Route { get }
    func respond(to request: RouteRequest<Self>) throws -> Response
}

public extension Responder {
    typealias GET = DeclarativeAPI.ResponderRoute<HTTPMethods.GET>
}

public extension Responder {
    func respond(
        to httpRequest: Vapor.Request
    ) throws -> EventLoopFuture<Vapor.Response> {
        let requestComponents = httpRequest.url.path.split(separator: "/").map(String.init)
        let request = try Request<Route.Method>(
            routerComponents: route.components,
            requestComponents: requestComponents,
            body: Route.Method.makeBody(from: httpRequest.body)
        )
        
        let container = RequestContainer(
            application: httpRequest.application,
            routerComponents: route.components,
            requestComponents: requestComponents
        )
        
        let appValues = ApplicationValues(app: httpRequest.application)
        container.setValue(appValues, forKey: ApplicationValuesKey.self)
        
        let encoder = PreEncoder()
        encoder.userInfo[.request] = container
        try self.encode(to: encoder)
        for containerBuilder in encoder.preEncodables {
            try containerBuilder.setProperties(in: container)
        }
        
        let routeRequest = RouteRequest<Self>(
            responder: self,
            request: request,
            container: container
        )
        
        return try respond(to: routeRequest).encodeResponse(for: httpRequest)
    }
}

public struct DelayedResponse<Response: RouteResponse>: RouteResponse {
    private let response: Response
    private let done: EventLoopFuture<Void>
    
    public init<R>(_ response: Response, untilSuccess: EventLoopFuture<R>) {
        self.response = response
        self.done = untilSuccess.transform(to: ())
    }
    
    public func encodeResponse(for request: Vapor.Request) -> EventLoopFuture<Vapor.Response> {
        return done.flatMap {
            response.encodeResponse(for: request)
        }
    }
}

@dynamicMemberLookup public struct RouteRequest<R: Responder> {
    let responder: R
    let request: Request<R.Route.Method>
    let container: RequestContainer
    
    public subscript<V: RequestProperty>(dynamicMember keyPath: KeyPath<R, V>) -> V.PresentedValue {
        responder[keyPath: keyPath].presentValue(from: container)
    }
}

fileprivate final class PreEncoder: Encoder {
    var codingPath: [CodingKey] { [] }
    var userInfo = [CodingUserInfoKey : Any]()
    var preEncodables = [RequestContainerBuilder]()
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        KeyedEncodingContainer(KeyedPreEncodingContainer<Key>(encoder: self))
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        BasicPreEncodingContainer(encoder: self)
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        BasicPreEncodingContainer(encoder: self)
    }
}

fileprivate struct KeyedPreEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let encoder: PreEncoder
    var codingPath: [CodingKey] { [] }
    
    mutating func encodeNil(forKey key: Key) throws {}
    mutating func encode(_ value: Bool, forKey key: Key) throws {}
    mutating func encode(_ value: String, forKey key: Key) throws {}
    mutating func encode(_ value: Double, forKey key: Key) throws {}
    mutating func encode(_ value: Float, forKey key: Key) throws {}
    mutating func encode(_ value: Int, forKey key: Key) throws {}
    mutating func encode(_ value: Int8, forKey key: Key) throws {}
    mutating func encode(_ value: Int16, forKey key: Key) throws {}
    mutating func encode(_ value: Int32, forKey key: Key) throws {}
    mutating func encode(_ value: Int64, forKey key: Key) throws {}
    mutating func encode(_ value: UInt, forKey key: Key) throws {}
    mutating func encode(_ value: UInt8, forKey key: Key) throws {}
    mutating func encode(_ value: UInt16, forKey key: Key) throws {}
    mutating func encode(_ value: UInt32, forKey key: Key) throws {}
    mutating func encode(_ value: UInt64, forKey key: Key) throws {}
    mutating func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
        if let value = value as? RequestContainerBuilder {
            encoder.preEncodables.append(value)
        }
        
        try value.encode(to: encoder)
    }
    
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        KeyedEncodingContainer(KeyedPreEncodingContainer<NestedKey>(encoder: encoder))
    }
    
    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        BasicPreEncodingContainer(encoder: encoder)
    }
    
    mutating func superEncoder() -> Encoder {
        encoder
    }
    
    mutating func superEncoder(forKey key: Key) -> Encoder {
        encoder
    }
}

fileprivate struct BasicPreEncodingContainer: UnkeyedEncodingContainer, SingleValueEncodingContainer {
    mutating func encode(_ value: String) throws {}
    mutating func encode(_ value: Double) throws {}
    mutating func encode(_ value: Float) throws {}
    mutating func encode(_ value: Int) throws {}
    mutating func encode(_ value: Int8) throws {}
    mutating func encode(_ value: Int16) throws {}
    mutating func encode(_ value: Int32) throws {}
    mutating func encode(_ value: Int64) throws {}
    mutating func encode(_ value: UInt) throws {}
    mutating func encode(_ value: UInt8) throws {}
    mutating func encode(_ value: UInt16) throws {}
    mutating func encode(_ value: UInt32) throws {}
    mutating func encode(_ value: UInt64) throws {}
    mutating func encodeNil() throws {}
    mutating func encode<T>(_ value: T) throws where T : Encodable {
        if let value = value as? RequestContainerBuilder {
            encoder.preEncodables.append(value)
        }
        
        try value.encode(to: encoder)
    }
    
    mutating func encode(_ value: Bool) throws {}
    
    let encoder: PreEncoder
    var codingPath: [CodingKey] { [] }
    var count: Int = 0
    
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        KeyedEncodingContainer(KeyedPreEncodingContainer<NestedKey>(encoder: encoder))
    }
    
    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        self
    }
    
    mutating func superEncoder() -> Encoder {
        encoder
    }
}
