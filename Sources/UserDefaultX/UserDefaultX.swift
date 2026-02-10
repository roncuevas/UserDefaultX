import Foundation
import Synchronization

public final class UserDefaultX: @unchecked Sendable {

    public static let standard = UserDefaultX()

    let defaults: UserDefaults
    let cache = CacheStore()
    private var observer: (any NSObjectProtocol)?
    let pendingWrites: Mutex<Int> = .init(0)

    // MARK: - Init

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: defaults,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            let shouldInvalidate = pendingWrites.withLock { count -> Bool in
                if count > 0 {
                    count -= 1
                    return false
                }
                return true
            }
            if shouldInvalidate {
                invalidateCache()
            }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    // MARK: - Read (typed)

    public func string(forKey key: String) -> String? {
        readThrough(key) { $0.string(forKey: key) }
    }

    public func integer(forKey key: String) -> Int {
        readThrough(key) { $0.integer(forKey: key) } ?? 0
    }

    public func double(forKey key: String) -> Double {
        readThrough(key) { $0.double(forKey: key) } ?? 0
    }

    public func float(forKey key: String) -> Float {
        readThrough(key) { $0.float(forKey: key) } ?? 0
    }

    public func bool(forKey key: String) -> Bool {
        readThrough(key) { $0.bool(forKey: key) } ?? false
    }

    public func data(forKey key: String) -> Data? {
        readThrough(key) { $0.data(forKey: key) }
    }

    public func url(forKey key: String) -> URL? {
        readThrough(key) { $0.url(forKey: key) }
    }

    public func array(forKey key: String) -> [Any]? {
        readThrough(key) { $0.array(forKey: key) }
    }

    public func dictionary(forKey key: String) -> [String: Any]? {
        readThrough(key) { $0.dictionary(forKey: key) }
    }

    public func object(forKey key: String) -> Any? {
        readThrough(key) { $0.object(forKey: key) }
    }

    // MARK: - Write (typed)

    public func set(_ value: String?, forKey key: String) {
        writeThrough(value, forKey: key) { $0.set(value, forKey: key) }
    }

    public func set(_ value: Int, forKey key: String) {
        writeThrough(value, forKey: key) { $0.set(value, forKey: key) }
    }

    public func set(_ value: Double, forKey key: String) {
        writeThrough(value, forKey: key) { $0.set(value, forKey: key) }
    }

    public func set(_ value: Float, forKey key: String) {
        writeThrough(value, forKey: key) { $0.set(value, forKey: key) }
    }

    public func set(_ value: Bool, forKey key: String) {
        writeThrough(value, forKey: key) { $0.set(value, forKey: key) }
    }

    public func set(_ value: Data?, forKey key: String) {
        writeThrough(value, forKey: key) { $0.set(value, forKey: key) }
    }

    public func set(_ value: URL?, forKey key: String) {
        writeThrough(value, forKey: key) { $0.set(value, forKey: key) }
    }

    public func set(_ value: Date?, forKey key: String) {
        writeThrough(value, forKey: key) { $0.set(value, forKey: key) }
    }

    public func set(_ value: Any?, forKey key: String) {
        writeThrough(value, forKey: key) { $0.set(value, forKey: key) }
    }

    // MARK: - Remove

    public func removeObject(forKey key: String) {
        pendingWrites.withLock { $0 += 1 }
        cache.remove(key)
        defaults.removeObject(forKey: key)
    }

    // MARK: - Query

    public func hasValue(forKey key: String) -> Bool {
        defaults.object(forKey: key) != nil
    }

    // MARK: - Cache management

    public func invalidateCache() {
        cache.invalidateAll()
    }

    public func invalidateCache(forKey key: String) {
        cache.invalidate(key)
    }

    public var statistics: CacheStatistics {
        cache.statistics
    }

    public func resetStatistics() {
        cache.resetStatistics()
    }

    // MARK: - Internal helpers

    private func readThrough<T>(_ key: String, fetch: (UserDefaults) -> T?) -> T? {
        let result = cache.get(key)
        if result.hit {
            return result.value as? T
        }
        let value = fetch(defaults)
        cache.set(value, forKey: key)
        return value
    }

    private func writeThrough(_ value: Any?, forKey key: String, persist: (UserDefaults) -> Void) {
        guard cache.set(value, forKey: key) else { return }
        pendingWrites.withLock { $0 += 1 }
        persist(defaults)
    }
}
