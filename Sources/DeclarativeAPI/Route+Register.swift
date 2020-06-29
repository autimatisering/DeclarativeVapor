import Vapor

extension Application {
    public func buildRoutes(@RoutesBuilder buildRoutes: () -> RouteGroup) {
        for route in buildRoutes().routes {
            let route = Vapor.Route(
                method: route.method,
                path: route.path,
                responder: route,
                requestType: Vapor.Request.self,
                responseType: Vapor.Response.self
            )
            
            self.add(route)
        }
    }
    
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

public struct DeclarativeRoutes {
    internal let routes: [DeclarativeResponderChain]
}

public struct DeclarativeMiddlewareChain {
    typealias InboundHandler = (Request, RequestContainer) -> EventLoopFuture<Void>
    
    private(set) var handler: InboundHandler
    
    private init(inboundHandler: @escaping InboundHandler) {
        self.handler = inboundHandler
    }
    
    public init<Inbound: InboundMiddleware>(inboundMiddleware: Inbound) {
        self.init { request, container in
            container.prepareTarget(
                inboundMiddleware,
                for: request
            ).flatMapThrowing {
                let request = MiddlewareRequest<Inbound>(
                    responder: inboundMiddleware,
                    body: request.body,
                    vapor: request,
                    container: container
                )
            
                return try inboundMiddleware.handleRequest(request)
            }
        }
    }
    
    public func appending<Inbound: InboundMiddleware>(inboundMiddleware: Inbound) -> Self {
        let next = DeclarativeMiddlewareChain(inboundMiddleware: inboundMiddleware)
        var chain = self
        chain.handler = { request, container in
            self.handler(request, container).flatMap {
                next.handler(request, container)
            }
        }
        return chain
    }
}

public struct DeclarativeResponderChain: Responder {
    typealias Handler = (Request, RequestContainer) -> EventLoopFuture<Response>
    
    let method: Vapor.HTTPMethod
    let path: [Vapor.PathComponent]
    let makeContainer: (Request) -> RequestContainer
    private(set) var handler: Handler
    
    internal init<R: DeclarativeResponder>(responder: R) {
        self.method = R.Route.Method.method
        self.path = responder.route.components.map { component in
            switch component.wrapped {
            case .value(let name, _):
                return Vapor.PathComponent.parameter(name)
            case .exact(let value):
                return Vapor.PathComponent.constant(value)
            }
        }
        self.handler = responder.respond
        self.makeContainer = { request in
            request.makeContainer(for: responder.route)
        }
    }
    
    public func injectMiddleware<Inbound: InboundMiddleware>(
        _ middleware: Inbound
    ) -> DeclarativeResponderChain {
        var copy = self
        let middleware =  DeclarativeMiddlewareChain(inboundMiddleware: middleware)
        copy.handler = { request, container in
            middleware.handler(request, container).flatMap {
                self.handler(request, container)
            }
        }
        return copy
    }
    
    public func respond(to request: Request) -> EventLoopFuture<Response> {
        return self.handler(request, makeContainer(request))
    }
}

public protocol RouteGroup {
    var routes: [DeclarativeResponderChain] { get }
}

public struct Grouped: RouteGroup {
    public let routes: [DeclarativeResponderChain]
    
    public init<Inbound: InboundMiddleware>(
        _ middleware: Inbound,
        @RoutesBuilder buildRoutes: () -> RouteGroup
    ) {
        self.routes = buildRoutes().routes.map { route in
            route.injectMiddleware(middleware)
        }
    }
    
    public init(@RoutesBuilder buildRoutes: () -> RouteGroup) {
        self.routes = buildRoutes().routes
    }
    
    init(routes: [DeclarativeResponderChain]) {
        self.routes = routes
    }
}

@_functionBuilder public struct RoutesBuilder {
    public static func buildBlock() -> RouteGroup {
        Grouped(routes: [])
    }
    
    public static func buildBlock(_ content: RouteGroup...) -> RouteGroup {
        Grouped(routes: content.reduce([]) {
            $0 + $1.routes
        })
    }
}
