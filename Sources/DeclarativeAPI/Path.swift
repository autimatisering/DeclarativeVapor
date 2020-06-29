import Vapor

public struct PathComponent: PathComponentRepresentable {
    internal enum _Component {
        case exact(String)
        case value(name: String, id: ObjectIdentifier)
    }
    
    internal let wrapped: _Component
    
    internal init(component: _Component) {
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

public protocol PathKey: RequestContainerKey where Value: LosslessStringConvertible {}

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
