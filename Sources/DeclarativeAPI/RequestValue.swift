import Vapor

public protocol RequestValue: RequestContainerKey {
    static func makeValue(from request: Vapor.Request) throws -> Value
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

public struct FailableRequestValue<SubValue: RequestValue>: RequestValue {
    public typealias Value = SubValue.Value?
    
    public static func makeValue(from request: Vapor.Request) throws -> SubValue.Value? {
        try? SubValue.makeValue(from: request)
    }
}

public typealias FailableRequestEnvironment<T: RequestValue> = RequestEnvironment<FailableRequestValue<T>>
