import Foundation
import Synchronization

struct CacheStore: Sendable {

    private let storage: Mutex<[String: any Sendable]> = .init([:])
    private let stats: Mutex<MutableStatistics> = .init(MutableStatistics())

    private struct MutableStatistics: Sendable {
        var hits: Int = 0
        var misses: Int = 0
        var skippedWrites: Int = 0
    }

    // MARK: - Sentinel

    static let nilSentinel: NSNull = NSNull()

    // MARK: - Read

    func get(_ key: String) -> (hit: Bool, value: Any?) {
        storage.withLock { cache in
            guard let cached = cache[key] else {
                stats.withLock { $0.misses += 1 }
                return (hit: false, value: nil)
            }
            stats.withLock { $0.hits += 1 }
            if cached is NSNull { return (hit: true, value: nil) }
            return (hit: true, value: cached)
        }
    }

    // MARK: - Write

    /// Stores the value in cache and returns `true` if it differs from the cached value (i.e. a disk write is needed).
    @discardableResult
    func set(_ value: Any?, forKey key: String) -> Bool {
        storage.withLock { cache in
            let boxed: any Sendable = (value as? (any Sendable)) ?? Self.nilSentinel
            if let existing = cache[key], Self.isEqual(existing, boxed) {
                stats.withLock { $0.skippedWrites += 1 }
                return false
            }
            cache[key] = boxed
            return true
        }
    }

    // MARK: - Remove

    func remove(_ key: String) {
        storage.withLock { cache in
            cache[key] = Self.nilSentinel
        }
    }

    // MARK: - Invalidation

    func invalidate(_ key: String) {
        storage.withLock { cache in
            cache.removeValue(forKey: key)
        }
    }

    func invalidateAll() {
        storage.withLock { cache in
            cache.removeAll()
        }
    }

    // MARK: - Statistics

    var statistics: CacheStatistics {
        stats.withLock { s in
            CacheStatistics(hits: s.hits, misses: s.misses, skippedWrites: s.skippedWrites)
        }
    }

    func resetStatistics() {
        stats.withLock { s in
            s.hits = 0
            s.misses = 0
            s.skippedWrites = 0
        }
    }

    // MARK: - Equality

    private static func isEqual(_ lhs: any Sendable, _ rhs: any Sendable) -> Bool {
        if lhs is NSNull, rhs is NSNull { return true }
        guard let lobj = lhs as? NSObject, let robj = rhs as? NSObject else { return false }
        return lobj.isEqual(robj)
    }
}
