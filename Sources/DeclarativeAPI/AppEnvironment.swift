import Vapor

public struct ApplicationValues {
    public let app: Application
    
    internal init(app: Application) {
        self.app = app
    }
}

internal struct ApplicationValuesKey: RequestContainerKey {
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
