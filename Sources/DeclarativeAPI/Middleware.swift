import Vapor

public protocol InboundMiddleware: RequestHandler {
    func handleRequest(_ request: MiddlewareRequest<Self>) throws
}

public protocol OutboundMiddleware: RequestHandler {
    func handleResponse(_ response: Response) throws
}

public protocol DuplexMiddleware: RequestHandler {
    mutating func handleRequest(_ request: MiddlewareRequest<Self>) throws
    mutating func handleResponse(_ response: Response) throws
}
