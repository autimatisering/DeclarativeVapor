import Vapor

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

public protocol RequestHandler: Encodable {}

public protocol DeclarativeResponder: RequestHandler, RouteGroup {
    associatedtype Route: DeclarativeAPI.RouteProtocol
    associatedtype Response: RouteResponse
    associatedtype Input: Decodable
    
    var route: Route { get }
    func respond(to request: RouteRequest<Self>) throws -> Response
}

extension DeclarativeResponder {
    public var routes: [DeclarativeResponderChain] {
        [DeclarativeResponderChain(responder: self)]
    }
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

extension Request {
    func makeContainer<R: RouteProtocol>(for route: R) -> RequestContainer {
        let requestComponents = self.url.path.split(separator: "/").map(String.init)
        
        let container = RequestContainer(
            application: self.application,
            eventLoop: self.eventLoop,
            routerComponents: route.components,
            requestComponents: requestComponents
        )
        
        let appValues = ApplicationValues(app: self.application)
        container.setValue(appValues, forKey: ApplicationValuesKey.self)
        container.setValue(self, forKey: RequestKey.self)
        
        return container
    }
}

extension DeclarativeResponder {
    func respond(to request: Vapor.Request) -> EventLoopFuture<Vapor.Response> {
        return respond(
            to: request,
            container: request.makeContainer(for: route)
        )
    }
    
    func respond(
        to request: Vapor.Request,
        container: RequestContainer
    ) -> EventLoopFuture<Vapor.Response> {
        container.prepareTarget(self, for: request).flatMapThrowing { () -> Self.Response in
            let request = RouteRequest<Self>(
                responder: self,
                body: try Route.Method.makeBody(from: request.body),
                vapor: request,
                container: container
            )
            
            return try self.respond(to: request)
        }.flatMap { response in
            response.encode(for: request).flatMapThrowing { encodable -> Vapor.Response in
                let response = Vapor.Response()
                try response.content.encode(encodable, as: .json)
                return response
            }
        }
    }
}

extension RequestContainer {
    func prepareTarget<Target: RequestHandler>(_ target: Target, for request: Request) -> EventLoopFuture<Void> {
        do {
            let builders = try findTargets(
                AsynchronousRequestContainerBuilder.self,
                in: target,
                userInfo: [
                    .request: self
                ]
            )
            var preEncoded = [EventLoopFuture<Void>]()
            
            for containerBuilder in builders {
                preEncoded.append(containerBuilder.asynchronouslySetProperties(in: self))
            }
            
            return EventLoopFuture.andAllSucceed(preEncoded, on: request.eventLoop)
        } catch {
            return eventLoop.future(error: error)
        }
    }
}
