public final class RequestContainer {
    let requestId: UUID
    let routerComponents: [PathComponent]
    let requestComponents: [String]
    let eventLoop: EventLoop
    var isActive = true
    var storage = [ObjectIdentifier: Any]()
    
    func setValue<Key: RequestContainerKey>(_ value: Key.Value, forKey type: Key.Type) {
        assert(isActive)
        self.storage[ObjectIdentifier(type)] = value
    }
    
    func getValue<Key: RequestContainerKey>(forKey type: Key.Type) -> Key.Value? {
        storage[ObjectIdentifier(type)] as? Key.Value
    }
    
    func containsValue<Key: RequestContainerKey>(forKey type: Key.Type) -> Bool {
        storage.keys.contains(ObjectIdentifier(type))
    }
    
    init(
        application: Application,
        eventLoop: EventLoop,
        routerComponents: [PathComponent],
        requestComponents: [String]
    ) {
        self.requestId = UUID()
        self.eventLoop = eventLoop
        self.routerComponents = routerComponents
        self.requestComponents = requestComponents
    }
}

protocol AsynchronousRequestContainerBuilder: Encodable {
    func asynchronouslySetProperties(in container: RequestContainer) -> EventLoopFuture<Void>
}

protocol RequestContainerBuilder: AsynchronousRequestContainerBuilder {
    func setProperties(in container: RequestContainer) throws
}

extension RequestContainerBuilder {
    func asynchronouslySetProperties(in container: RequestContainer) -> EventLoopFuture<Void> {
        do {
            try setProperties(in: container)
            return container.eventLoop.makeSucceededFuture(())
        } catch {
            return container.eventLoop.makeFailedFuture(error)
        }
    }
}

extension CodingUserInfoKey {
    static let request = CodingUserInfoKey(rawValue: "delcarative-custom-encodable-request")!
}

extension RequestContainerBuilder {
    public func encode(to encoder: Encoder) throws { }
}
