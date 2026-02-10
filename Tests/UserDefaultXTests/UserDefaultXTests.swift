import Testing
import Foundation
@testable import UserDefaultX

@Suite("UserDefaultX Core Tests")
struct UserDefaultXTests {

    private let suiteName = "com.userdefaultx.tests.\(UUID().uuidString)"

    private func makeSUT() -> (UserDefaultX, UserDefaults) {
        let defaults = UserDefaults(suiteName: suiteName)!
        let sut = UserDefaultX(defaults: defaults)
        return (sut, defaults)
    }

    private func cleanup(_ defaults: UserDefaults) {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - String

    @Test func stringReadWrite() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        sut.set("hello", forKey: "key")
        #expect(sut.string(forKey: "key") == "hello")
    }

    @Test func stringReturnsNilWhenMissing() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        #expect(sut.string(forKey: "missing") == nil)
    }

    // MARK: - Integer

    @Test func integerReadWrite() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        sut.set(42, forKey: "int")
        #expect(sut.integer(forKey: "int") == 42)
    }

    @Test func integerDefaultsToZero() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        #expect(sut.integer(forKey: "missing") == 0)
    }

    // MARK: - Double

    @Test func doubleReadWrite() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        sut.set(3.14, forKey: "pi")
        #expect(sut.double(forKey: "pi") == 3.14)
    }

    // MARK: - Float

    @Test func floatReadWrite() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        sut.set(Float(2.5), forKey: "f")
        #expect(sut.float(forKey: "f") == 2.5)
    }

    // MARK: - Bool

    @Test func boolReadWrite() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        sut.set(true, forKey: "flag")
        #expect(sut.bool(forKey: "flag") == true)
    }

    @Test func boolDefaultsToFalse() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        #expect(sut.bool(forKey: "missing") == false)
    }

    // MARK: - Data

    @Test func dataReadWrite() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        let data = Data([0x01, 0x02, 0x03])
        sut.set(data, forKey: "data")
        #expect(sut.data(forKey: "data") == data)
    }

    // MARK: - URL

    @Test func urlReadWrite() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        let url = URL(string: "https://example.com")!
        sut.set(url, forKey: "url")
        #expect(sut.url(forKey: "url") == url)
    }

    // MARK: - Date

    @Test func dateReadWrite() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        let date = Date(timeIntervalSince1970: 1_000_000)
        sut.set(date, forKey: "date")
        let retrieved = sut.object(forKey: "date") as? Date
        #expect(retrieved == date)
    }

    // MARK: - Cache hit / miss

    @Test func cacheHitOnSecondRead() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        sut.resetStatistics()
        sut.set("value", forKey: "k")
        _ = sut.string(forKey: "k") // hit (cached from write)
        _ = sut.string(forKey: "k") // hit again

        let stats = sut.statistics
        #expect(stats.hits == 2)
        #expect(stats.misses == 0)
    }

    @Test func cacheMissOnFirstRead() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        defaults.set("direct", forKey: "k")
        sut.resetStatistics()

        let value = sut.string(forKey: "k") // miss → read from defaults → cache
        #expect(value == "direct")
        #expect(sut.statistics.misses == 1)

        _ = sut.string(forKey: "k") // hit
        #expect(sut.statistics.hits == 1)
    }

    // MARK: - Skipped writes

    @Test func skipsRedundantWrite() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        sut.set("same", forKey: "k")
        sut.resetStatistics()

        sut.set("same", forKey: "k") // should be skipped
        #expect(sut.statistics.skippedWrites == 1)
    }

    @Test func writesWhenValueChanges() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        sut.set("a", forKey: "k")
        sut.resetStatistics()

        sut.set("b", forKey: "k") // different value → write
        #expect(sut.statistics.skippedWrites == 0)
        #expect(sut.string(forKey: "k") == "b")
    }

    // MARK: - Nil sentinel

    @Test func nilValueIsCachedAsSentinel() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        _ = sut.string(forKey: "none") // miss → caches nil sentinel
        sut.resetStatistics()

        let value = sut.string(forKey: "none") // should be cache hit returning nil
        #expect(value == nil)
        #expect(sut.statistics.hits == 1)
        #expect(sut.statistics.misses == 0)
    }

    // MARK: - Remove

    @Test func removeObjectClearsCacheAndDefaults() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        sut.set("value", forKey: "k")
        sut.removeObject(forKey: "k")

        #expect(sut.string(forKey: "k") == nil)
        #expect(defaults.object(forKey: "k") == nil)
    }

    // MARK: - Invalidation

    @Test func invalidateCacheForcesReread() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        sut.set("cached", forKey: "k")
        sut.resetStatistics()

        // Invalidate the cache for this key
        sut.invalidateCache(forKey: "k")

        // Next read should be a cache miss → re-read from defaults
        let value = sut.string(forKey: "k")
        #expect(value == "cached") // still "cached" in defaults
        #expect(sut.statistics.misses == 1)
    }

    @Test func externalWriteInvalidatesCacheViaNotification() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        sut.set("original", forKey: "k")

        // External write triggers didChangeNotification → cache invalidated
        defaults.set("external", forKey: "k")

        // Next read should pick up the external value
        #expect(sut.string(forKey: "k") == "external")
    }

    @Test func invalidateAllClearsEntireCache() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        sut.set("a", forKey: "k1")
        sut.set("b", forKey: "k2")

        defaults.set("x", forKey: "k1")
        defaults.set("y", forKey: "k2")

        sut.invalidateCache()

        #expect(sut.string(forKey: "k1") == "x")
        #expect(sut.string(forKey: "k2") == "y")
    }

    // MARK: - hasValue

    @Test func hasValueReturnsTrueWhenExists() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        sut.set("v", forKey: "k")
        #expect(sut.hasValue(forKey: "k") == true)
    }

    @Test func hasValueReturnsFalseWhenMissing() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        #expect(sut.hasValue(forKey: "missing") == false)
    }

    // MARK: - Statistics

    @Test func hitRateComputation() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }
        sut.resetStatistics()

        sut.set("v", forKey: "k")
        _ = sut.string(forKey: "k")     // hit
        _ = sut.string(forKey: "other") // miss

        let stats = sut.statistics
        #expect(stats.hits == 1)
        #expect(stats.misses == 1)
        #expect(stats.hitRate == 0.5)
    }

    @Test func resetStatisticsClearsCounters() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        _ = sut.string(forKey: "k")
        sut.resetStatistics()

        let stats = sut.statistics
        #expect(stats.hits == 0)
        #expect(stats.misses == 0)
        #expect(stats.skippedWrites == 0)
    }

    // MARK: - object(forKey:)

    @Test func objectReadWrite() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        sut.set([1, 2, 3] as Any?, forKey: "arr")
        let result = sut.object(forKey: "arr") as? [Int]
        #expect(result == [1, 2, 3])
    }
}
