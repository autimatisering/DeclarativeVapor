@_exported import Vapor
import Foundation

public typealias HTTPBody = Vapor.Request.Body

public protocol RequestProperty {
    associatedtype PresentedValue
    func presentValue(from container: RequestContainer) -> PresentedValue
}

public protocol RequestContainerKey {
    associatedtype Value
}

struct RequestKey: RequestContainerKey {
    typealias Value = Vapor.Request
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

@dynamicMemberLookup public struct MiddlewareRequest<R: RequestHandler> {
    let responder: R
    public let body: HTTPBody
    let vapor: Request
    let container: RequestContainer
    
    public subscript<V: RequestProperty>(dynamicMember keyPath: KeyPath<R, V>) -> V.PresentedValue {
        responder[keyPath: keyPath].presentValue(from: container)
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

extension Asynchronous: ResponseEncodable, RouteResponse, AsynchronousEncodable where Result: AsynchronousEncodable {
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
