import Foundation

@propertyWrapper
public struct DefaultX<Value: Sendable>: Sendable {

    private let key: String
    private let defaultValue: Value
    private let store: UserDefaultX

    public init(wrappedValue: Value, _ key: String, store: UserDefaultX = .standard) {
        self.key = key
        self.defaultValue = wrappedValue
        self.store = store
    }

    public var wrappedValue: Value {
        get { store.object(forKey: key) as? Value ?? defaultValue }
        set { store.set(newValue, forKey: key) }
    }
}

@propertyWrapper
public struct DefaultXCodable<Value: Codable & Sendable>: Sendable {

    private let key: String
    private let defaultValue: Value
    private let store: UserDefaultX

    public init(wrappedValue: Value, _ key: String, store: UserDefaultX = .standard) {
        self.key = key
        self.defaultValue = wrappedValue
        self.store = store
    }

    public var wrappedValue: Value {
        get { (store.codable(forKey: key) as Value?) ?? defaultValue }
        set { store.setCodable(newValue, forKey: key) }
    }
}
