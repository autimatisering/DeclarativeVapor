import DeclarativeAPI

@_functionBuilder
public struct JSONObjectBuilder {
    public static func buildBlock() -> EventualJSONObject {
        EventualJSONObject(values: [])
    }
    
    public static func buildBlock(_ content: JSONKey...) -> EventualJSONObject {
        EventualJSONObject(values: content)
    }
}

public func JSONObject(@JSONObjectBuilder _ build: () -> EventualJSONObject) -> EventualJSONObject {
    build()
}

public struct _FinalizedJSONObject: Encodable {
    fileprivate let pairs: [String: _EncodeFunction]
    
    private struct CustomKey: CodingKey {
        init?(intValue: Int) {
            nil
        }
        
        init(stringValue: String) {
            self.stringValue = stringValue
        }
        
        var stringValue: String
        var intValue: Int? { nil }
    }
    
    private struct _EncodeContainer: Encodable {
        let _encode: _EncodeFunction
        
        func encode(to encoder: Encoder) throws {
            try _encode(encoder)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CustomKey.self)
        
        for (key, value) in pairs {
            let key = CustomKey(stringValue: key)
            try container.encode(_EncodeContainer(_encode: value), forKey: key)
        }
    }
}

public struct EventualJSONObject: RouteResponse {
    public typealias E = _FinalizedJSONObject
    let values: [JSONKey]
    
    public func encode(for request: Request) -> EventLoopFuture<E> {
        let pairs = values.map { value in
            value.jsonValue(for: request)
        }
        
        return EventLoopFuture.whenAllSucceed(pairs, on: request.eventLoop).map { pairs -> _FinalizedJSONObject in
            var object = [String: _EncodeFunction]()
            
            for (key, value) in pairs {
                assert(!object.keys.contains(key), "Duplicate key in JSONObject, will overwrite key \"\(key)\"")
                object[key] = value
            }
            
            return _FinalizedJSONObject(pairs: object)
        }
    }
}

fileprivate protocol EventualJSONPair {
    func jsonValue(for request: Request) -> EventLoopFuture<(String, _EncodeFunction)>
}

public struct JSONKey: EventualJSONPair {
    private var makeValue: (Request) -> EventLoopFuture<(String, _EncodeFunction)>
    
    public func jsonValue(for request: Request) -> EventLoopFuture<(String, _EncodeFunction)> {
        makeValue(request)
    }
    
    public init<RE: RouteResponse>(_ key: String, value: RE) {
        self.makeValue = { request in
            value.encode(for: request).flatMapThrowing { value in
                return (key, value.encode)
            }
        }
    }
    
    public init<RE: RouteResponse>(_ key: String, build: () -> RE) {
        self.init(key, value: build())
    }
}

public typealias _EncodeFunction = (Encoder) throws -> ()
