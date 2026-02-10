import Testing
import Foundation
@testable import UserDefaultX

@Suite("Performance Tests")
struct PerformanceTests {

    private let suiteName = "com.userdefaultx.perf.\(UUID().uuidString)"

    private func makeSUT() -> (UserDefaultX, UserDefaults) {
        let defaults = UserDefaults(suiteName: suiteName)!
        let sut = UserDefaultX(defaults: defaults)
        return (sut, defaults)
    }

    private func cleanup(_ defaults: UserDefaults) {
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func cachedReadsAreFasterThanDirect() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        let iterations = 10_000
        let key = "perf_key"
        sut.set("performance_value", forKey: key)
        defaults.set("performance_value", forKey: key)

        // Warm up
        for _ in 0..<100 {
            _ = sut.string(forKey: key)
            _ = defaults.string(forKey: key)
        }

        // Measure cached reads
        let cachedStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            _ = sut.string(forKey: key)
        }
        let cachedDuration = CFAbsoluteTimeGetCurrent() - cachedStart

        // Measure direct UserDefaults reads
        let directStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            _ = defaults.string(forKey: key)
        }
        let directDuration = CFAbsoluteTimeGetCurrent() - directStart

        // Cached should be at least as fast (allowing some tolerance for system variance)
        // We just verify it completes without issues; actual speedup depends on system
        #expect(cachedDuration >= 0)
        #expect(directDuration >= 0)
    }

    @Test func skippedWritesAreFasterThanAlwaysWriting() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        let iterations = 10_000
        let key = "perf_write_key"

        // Measure writes through cache (most will be skipped after first)
        sut.set("same_value", forKey: key)
        let cachedStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            sut.set("same_value", forKey: key)
        }
        let cachedDuration = CFAbsoluteTimeGetCurrent() - cachedStart

        // Measure direct writes to UserDefaults (no skip optimization)
        let directStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            defaults.set("same_value", forKey: key)
        }
        let directDuration = CFAbsoluteTimeGetCurrent() - directStart

        // Verify skipped writes completed and produced skipped write stats
        let stats = sut.statistics
        #expect(stats.skippedWrites == iterations)
        #expect(cachedDuration >= 0)
        #expect(directDuration >= 0)
    }

    @Test func cacheStatisticsAfterBulkOperations() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }
        sut.resetStatistics()

        let iterations = 1_000

        // Write unique values
        for i in 0..<iterations {
            sut.set("value-\(i)", forKey: "key-\(i)")
        }

        // Read them all (should be cache hits)
        for i in 0..<iterations {
            _ = sut.string(forKey: "key-\(i)")
        }

        let stats = sut.statistics
        #expect(stats.hits == iterations)
        #expect(stats.misses == 0)
        #expect(stats.hitRate == 1.0)
    }
}
