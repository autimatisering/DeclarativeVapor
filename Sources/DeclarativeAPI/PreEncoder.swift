public func findTargets<Target, Parent: Encodable>(
    _ type: Target.Type,
    in parent: Parent,
    userInfo: [CodingUserInfoKey : Any] = [:]
) throws -> [Target] {
    let encoder = PreEncoder<Target>()
    encoder.userInfo = userInfo
    try parent.encode(to: encoder)
    return encoder.preEncodables
}

fileprivate final class PreEncoder<Target>: Encoder {
    var codingPath: [CodingKey] { [] }
    var userInfo = [CodingUserInfoKey : Any]()
    var preEncodables = [Target]()
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        KeyedEncodingContainer(KeyedPreEncodingContainer<Target, Key>(encoder: self))
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        BasicPreEncodingContainer(encoder: self)
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        BasicPreEncodingContainer(encoder: self)
    }
}

fileprivate struct KeyedPreEncodingContainer<Target, Key: CodingKey>: KeyedEncodingContainerProtocol {
    let encoder: PreEncoder<Target>
    var codingPath: [CodingKey] { [] }
    
    mutating func encodeNil(forKey key: Key) throws {}
    mutating func encode(_ value: Bool, forKey key: Key) throws {}
    mutating func encode(_ value: String, forKey key: Key) throws {}
    mutating func encode(_ value: Double, forKey key: Key) throws {}
    mutating func encode(_ value: Float, forKey key: Key) throws {}
    mutating func encode(_ value: Int, forKey key: Key) throws {}
    mutating func encode(_ value: Int8, forKey key: Key) throws {}
    mutating func encode(_ value: Int16, forKey key: Key) throws {}
    mutating func encode(_ value: Int32, forKey key: Key) throws {}
    mutating func encode(_ value: Int64, forKey key: Key) throws {}
    mutating func encode(_ value: UInt, forKey key: Key) throws {}
    mutating func encode(_ value: UInt8, forKey key: Key) throws {}
    mutating func encode(_ value: UInt16, forKey key: Key) throws {}
    mutating func encode(_ value: UInt32, forKey key: Key) throws {}
    mutating func encode(_ value: UInt64, forKey key: Key) throws {}
    mutating func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
        if let value = value as? Target {
            encoder.preEncodables.append(value)
        }
        
        try value.encode(to: encoder)
    }
    
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        KeyedEncodingContainer(KeyedPreEncodingContainer<Target, NestedKey>(encoder: encoder))
    }
    
    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        BasicPreEncodingContainer(encoder: encoder)
    }
    
    mutating func superEncoder() -> Encoder {
        encoder
    }
    
    mutating func superEncoder(forKey key: Key) -> Encoder {
        encoder
    }
}

fileprivate struct BasicPreEncodingContainer<Target>: UnkeyedEncodingContainer, SingleValueEncodingContainer {
    mutating func encode(_ value: String) throws {}
    mutating func encode(_ value: Double) throws {}
    mutating func encode(_ value: Float) throws {}
    mutating func encode(_ value: Int) throws {}
    mutating func encode(_ value: Int8) throws {}
    mutating func encode(_ value: Int16) throws {}
    mutating func encode(_ value: Int32) throws {}
    mutating func encode(_ value: Int64) throws {}
    mutating func encode(_ value: UInt) throws {}
    mutating func encode(_ value: UInt8) throws {}
    mutating func encode(_ value: UInt16) throws {}
    mutating func encode(_ value: UInt32) throws {}
    mutating func encode(_ value: UInt64) throws {}
    mutating func encodeNil() throws {}
    mutating func encode<T>(_ value: T) throws where T : Encodable {
        if let value = value as? Target {
            encoder.preEncodables.append(value)
        }
        
        try value.encode(to: encoder)
    }
    
    mutating func encode(_ value: Bool) throws {}
    
    let encoder: PreEncoder<Target>
    var codingPath: [CodingKey] { [] }
    var count: Int = 0
    
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        KeyedEncodingContainer(KeyedPreEncodingContainer<Target, NestedKey>(encoder: encoder))
    }
    
    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        self
    }
    
    mutating func superEncoder() -> Encoder {
        encoder
    }
}
