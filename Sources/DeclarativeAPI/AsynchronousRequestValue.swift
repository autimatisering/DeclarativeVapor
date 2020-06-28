import Vapor

public protocol AsynchronousRequestValue: RequestContainerKey {
    static func makeValue(from request: Vapor.Request) -> EventLoopFuture<Value>
}

@propertyWrapper public struct AsynchronousRequestEnvironment<Key: AsynchronousRequestValue>: RequestProperty, AsynchronousRequestContainerBuilder {
    public typealias PresentedValue = Key.Value
    
    public var wrappedValue: Self { self }
    
    public init(_ type: Key.Type) { }
    
    public func presentValue(from container: RequestContainer) -> PresentedValue {
        guard let value = container.getValue(forKey: Key.self) else {
            fatalError("_Route parameter is requested before the execution of a request")
        }
        
        return value
    }
    
    func asynchronouslySetProperties(in container: RequestContainer) -> EventLoopFuture<Void> {
        if container.containsValue(forKey: RequestKey.self) {
            return container.eventLoop.makeSucceededFuture(())
        }
        
        guard let request = container.getValue(forKey: RequestKey.self) else {
            return container.eventLoop.future(error: CustomRouterError.missingRequest)
        }
        
        return Key.makeValue(from: request).map { value in
            return container.setValue(value, forKey: Key.self)
        }
    }
}
