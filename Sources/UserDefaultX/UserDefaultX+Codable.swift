import Foundation

extension UserDefaultX {

    public func codable<T: Codable & Sendable>(forKey key: String) -> T? {
        let result = cache.get(key)
        if result.hit {
            guard let data = result.value as? Data else { return nil }
            return try? JSONDecoder().decode(T.self, from: data)
        }
        guard let data = defaults.data(forKey: key) else {
            cache.set(Optional<Data>.none, forKey: key)
            return nil
        }
        cache.set(data, forKey: key)
        return try? JSONDecoder().decode(T.self, from: data)
    }

    public func setCodable<T: Codable & Sendable>(_ value: T?, forKey key: String) {
        guard let value else {
            removeObject(forKey: key)
            return
        }
        guard let data = try? JSONEncoder().encode(value) else { return }
        guard cache.set(data, forKey: key) else { return }
        pendingWrites.withLock { $0 += 1 }
        defaults.set(data, forKey: key)
    }
}
