import Foundation
import Synchronization

final class CacheStore: Sendable {

    private struct Box: @unchecked Sendable {
        let value: Any
    }

    private struct State: Sendable {
        var cache: [String: Box] = [:]
        var hits: Int = 0
        var misses: Int = 0
        var skippedWrites: Int = 0
    }

    private let state: Mutex<State> = .init(State())

    // MARK: - Sentinel

    private static let nilSentinel = NSNull()

    // MARK: - Read

    func get(_ key: String) -> (hit: Bool, value: Any?) {
        state.withLock { s in
            guard let box = s.cache[key] else {
                s.misses += 1
                return (hit: false, value: nil)
            }
            s.hits += 1
            if box.value is NSNull { return (hit: true, value: nil) }
            return (hit: true, value: box.value)
        }
    }

    // MARK: - Write

    /// Stores the value in cache and returns `true` if it differs from the cached value (i.e. a disk write is needed).
    @discardableResult
    func set(_ value: Any?, forKey key: String) -> Bool {
        state.withLock { s in
            let raw: Any = value ?? Self.nilSentinel
            if let existing = s.cache[key], Self.isEqual(existing.value, raw) {
                s.skippedWrites += 1
                return false
            }
            s.cache[key] = Box(value: raw)
            return true
        }
    }

    // MARK: - Remove

    func remove(_ key: String) {
        state.withLock { $0.cache[key] = Box(value: Self.nilSentinel) }
    }

    // MARK: - Invalidation

    func invalidate(_ key: String) {
        state.withLock { _ = $0.cache.removeValue(forKey: key) }
    }

    func invalidateAll() {
        state.withLock { $0.cache.removeAll() }
    }

    // MARK: - Statistics

    var statistics: CacheStatistics {
        state.withLock { s in
            CacheStatistics(hits: s.hits, misses: s.misses, skippedWrites: s.skippedWrites)
        }
    }

    func resetStatistics() {
        state.withLock { s in
            s.hits = 0
            s.misses = 0
            s.skippedWrites = 0
        }
    }

    // MARK: - Equality

    private static func isEqual(_ lhs: Any, _ rhs: Any) -> Bool {
        if lhs is NSNull, rhs is NSNull { return true }
        guard let lobj = lhs as? NSObject, let robj = rhs as? NSObject else { return false }
        return lobj.isEqual(robj)
    }
}
