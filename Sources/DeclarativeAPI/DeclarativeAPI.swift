@_exported import Vapor
import Foundation

public typealias HTTPBody = Vapor.Request.Body

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

protocol Middleware {
    associatedtype Input
    associatedtype Output
    
    static func transformInput(_ input: Input) -> Output
}

public struct PathComponent: PathComponentRepresentable {
    fileprivate enum _Component {
        case exact(String)
        case value(name: String, id: ObjectIdentifier)
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

enum CustomRouterError: Error {
    case pathComponentDecodeFailure(input: String, output: Any.Type)
    case invalidHttpMethod(provided: String, needed: String)
    case unexpectedBodyProvided
    case missingBody
    case missingPathComponent(Any.Type)
    case missingRequest
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
public protocol RequestValue: RequestContainerKey {
    static func makeValue(from request: Vapor.Request) throws -> Value
}

fileprivate struct RequestKey: RequestContainerKey {
    typealias Value = Vapor.Request
}

@propertyWrapper public struct RequestEnvironment<Key: RequestValue>: RequestProperty, RequestContainerBuilder {
    public typealias PresentedValue = Key.Value
    
    public var wrappedValue: Self { self }
    
    public init(_ type: Key.Type) { }
    
    public func presentValue(from container: RequestContainer) -> PresentedValue {
        guard let value = container.getValue(forKey: Key.self) else {
            fatalError("_Route parameter is requested before the execution of a request")
        }
        
        return value
    }
    
    func setProperties(in container: RequestContainer) throws {
        guard let request = container.getValue(forKey: RequestKey.self) else {
            throw CustomRouterError.missingRequest
        }
        
        let value = try Key.makeValue(from: request)
        container.setValue(value, forKey: Key.self)
    }
}

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
        .init(component: .value(name: "\(Self.self)", id: ObjectIdentifier(Key.self)))
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
            guard case let .value(_, typeId) = component.wrapped, typeId == keyId else {
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

public protocol AsynchronousEncodable {
    associatedtype E: Encodable
    
    func encode(for request: Request) -> EventLoopFuture<E>
}

public protocol RouteResponse: AsynchronousEncodable {}

public protocol RouteContent: Content, RouteResponse where E == Self {}
extension RouteContent {
    public func encode(for request: Request) -> EventLoopFuture<E> {
        request.eventLoop.future(self)
    }
    
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        encode(for: request).flatMapThrowing { (encodable: E) in
            let response = Response()
            try response.content.encode(encodable, as: .json)
            return response
        }
    }
}

public protocol DeclarativeResponder: Encodable {
    associatedtype Route: DeclarativeAPI.RouteProtocol
    associatedtype Response: RouteResponse
    associatedtype Input: Decodable
    
    var route: Route { get }
    func respond(to request: RouteRequest<Self>) throws -> Response
}

extension Never: Decodable {
    public init(from decoder: Decoder) throws {
        fatalError()
    }
}

public protocol GetResponder: DeclarativeAPI.DeclarativeResponder where Route == ResponderRoute<HTTPMethods.GET>, Input == Never {
    typealias GetRoute = ResponderRoute<HTTPMethods.GET>
    func makeRoute() -> GetRoute
}

extension GetResponder {
    public var route: Route {
        makeRoute()
    }
}

public protocol PostResponder: DeclarativeAPI.DeclarativeResponder where Route == ResponderRoute<HTTPMethods.POST<Input>> {
    typealias PostRoute = ResponderRoute<HTTPMethods.POST<Input>>
    func makeRoute() -> PostRoute
}

extension PostResponder {
    public var route: Route {
        makeRoute()
    }
}

public extension DeclarativeResponder {
    func respond(
        to httpRequest: Vapor.Request
    ) -> EventLoopFuture<Vapor.Response> {
        do {
            let requestComponents = httpRequest.url.path.split(separator: "/").map(String.init)
            
            let container = RequestContainer(
                application: httpRequest.application,
                routerComponents: route.components,
                requestComponents: requestComponents
            )
            
            let appValues = ApplicationValues(app: httpRequest.application)
            container.setValue(appValues, forKey: ApplicationValuesKey.self)
            container.setValue(httpRequest, forKey: RequestKey.self)
            
            let encoder = PreEncoder()
            encoder.userInfo[.request] = container
            try self.encode(to: encoder)
            for containerBuilder in encoder.preEncodables {
                try containerBuilder.setProperties(in: container)
            }
            
            let routeRequest = RouteRequest<Self>(
                responder: self,
                body: try Route.Method.makeBody(from: httpRequest.body),
                vapor: httpRequest,
                container: container
            )
            
            return try respond(to: routeRequest)
                .encode(for: httpRequest)
                .flatMapThrowing { encodable in
                    let response = Vapor.Response()
                    try response.content.encode(encodable, as: .json)
                    return response
                }
        } catch {
            return httpRequest.eventLoop.future(error: error)
        }
    }
}

public protocol _AsynchronousResult {
    associatedtype Result
    
    var result: EventLoopFuture<Result> { get }
}

public struct DelayedResult<Result>: _AsynchronousResult {
    private let response: Result
    private let done: EventLoopFuture<Void>
    public var result: EventLoopFuture<Result> {
        done.transform(to: response)
    }
    
    public init<R>(_ response: Result, untilSuccess: EventLoopFuture<R>) {
        self.response = response
        self.done = untilSuccess.transform(to: ())
    }
}

extension DelayedResult: AsynchronousEncodable where Result: AsynchronousEncodable {
    public func encode(for request: Request) -> EventLoopFuture<Result.E> {
        result.flatMap {
            $0.encode(for: request)
        }
    }
}

extension DelayedResult: ResponseEncodable, RouteResponse where Result: RouteResponse {
    public func encode(for request: Request) -> EventLoopFuture<Result.E> {
        result.flatMap {
            $0.encode(for: request)
        }
    }
    
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        encode(for: request).flatMapThrowing { (encodable: E) in
            let response = Response()
            try response.content.encode(encodable, as: .json)
            return response
        }
    }
}

@dynamicMemberLookup public struct RouteRequest<R: DeclarativeResponder> {
    let responder: R
    public let body: R.Route.Method.InputBody
    let vapor: Request
    let container: RequestContainer
    
    public subscript<V: RequestProperty>(dynamicMember keyPath: KeyPath<R, V>) -> V.PresentedValue {
        responder[keyPath: keyPath].presentValue(from: container)
    }
}

extension RouteResponse {
    public func flatten(on request: Request) -> Asynchronous<E> {
        Asynchronous(encode(for: request))
    }
    
    public func flatten<T>(on request: RouteRequest<T>) -> Asynchronous<E> {
        flatten(on: request.vapor)
    }
}

@dynamicMemberLookup public struct Asynchronous<Result>: _AsynchronousResult {
    public let result: EventLoopFuture<Result>
    
    public init(_ result: EventLoopFuture<Result>) {
        self.result = result
    }
    
    public subscript<T>(dynamicMember keyPath: KeyPath<Result, T>) -> Asynchronous<T> {
        Asynchronous<T>(result.map { $0[keyPath: keyPath] })
    }
}

extension Asynchronous: ResponseEncodable, RouteResponse, AsynchronousEncodable where Result: RouteResponse {
    public func encode(for request: Request) -> EventLoopFuture<Result.E> {
        result.flatMap {
            $0.encode(for: request)
        }
    }
    
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        encode(for: request).flatMapThrowing { (encodable: E) in
            let response = Response()
            try response.content.encode(encodable, as: .json)
            return response
        }
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

extension Application {
    public func register<Responder: DeclarativeAPI.DeclarativeResponder>(
        _ responder: Responder
    ) {
        let route = Vapor.Route(
            method: Responder.Route.Method.method,
            path: responder.route.components.map { component in
                switch component.wrapped {
                case .value(let name, _):
                    return Vapor.PathComponent.parameter(name)
                case .exact(let value):
                    return Vapor.PathComponent.constant(value)
                }
            },
            responder: BasicResponder(closure: responder.respond),
            requestType: Vapor.Request.self,
            responseType: Vapor.Response.self
        )
        
        self.add(route)
    }
}

public struct FailableRequestValue<SubValue: RequestValue>: RequestValue {
    public typealias Value = SubValue.Value?
    
    public static func makeValue(from request: Vapor.Request) throws -> SubValue.Value? {
        try? SubValue.makeValue(from: request)
    }
}

public typealias FailableRequestEnvironment<T: RequestValue> = RequestEnvironment<FailableRequestValue<T>>
