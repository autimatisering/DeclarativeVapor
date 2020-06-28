import DeclarativeAPI
import IkigaJSON

@_functionBuilder
public struct JSONObjectBuilder {
    public static func buildBlock() -> IkigaJSON.JSONObject {
        return IkigaJSON.JSONObject()
    }
    
    public static func buildBlock(_ content: JSONKey...) -> EventualJSONObject {
        EventualJSONObject(values: content)
    }
}

public func JSONObject(@JSONObjectBuilder _ build: () -> EventualJSONObject) -> EventualJSONObject {
    build()
}

public struct EventualJSONObject: RouteResponse {
    public typealias E = JSONObject
    let values: [JSONKey]
    
    public func encode(for request: Request) -> EventLoopFuture<E> {
        let pairs = values.map { value in
            value.jsonValue(for: request)
        }
        
        return EventLoopFuture.whenAllSucceed(pairs, on: request.eventLoop).map { pairs -> JSONObject in
            var object = JSONObject()
            
            for (key, value) in pairs {
                assert(!object.keys.contains(key), "Duplicate key in JSONObject, will overwrite key \"\(key)\"")
                object[key] = value
            }
            
            return object
        }
    }
}

public protocol EventualJSONPair {
    func jsonValue(for request: Request) -> EventLoopFuture<(String, JSONValue)>
}

public struct JSONKey: EventualJSONPair {
    private var makeValue: (Request) -> EventLoopFuture<(String, JSONValue)>
    
    public func jsonValue(for request: Request) -> EventLoopFuture<(String, JSONValue)> {
        makeValue(request)
    }
    
    public init<RE: RouteResponse>(_ key: String, build: () -> RE) {
        let value = build()
        self.makeValue = { request in
            value.encode(for: request).flatMapThrowing { value in
                let value = try IkigaJSONEncoder().encodeJSONValue(from: value)
                return (key, value)
            }
        }
//        build().
    }
}

extension IkigaJSONEncoder {
    public func encodeJSONValue<E: Encodable>(from encodable: E) throws -> JSONValue {
        fatalError()
    }
}

extension JSONObject: Encodable {
    public func encode(to encoder: Encoder) throws {
        fatalError()
    }
}
