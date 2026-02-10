import Testing
import Foundation
@testable import UserDefaultX

@Suite("Codable Tests")
struct CodableTests {

    private let suiteName = "com.userdefaultx.codable.\(UUID().uuidString)"

    private func makeSUT() -> (UserDefaultX, UserDefaults) {
        let defaults = UserDefaults(suiteName: suiteName)!
        let sut = UserDefaultX(defaults: defaults)
        return (sut, defaults)
    }

    private func cleanup(_ defaults: UserDefaults) {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Model

    struct Settings: Codable, Sendable, Equatable {
        var theme: String
        var fontSize: Int
    }

    // MARK: - Read / Write

    @Test func codableRoundTrip() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        let settings = Settings(theme: "dark", fontSize: 14)
        sut.setCodable(settings, forKey: "settings")

        let retrieved: Settings? = sut.codable(forKey: "settings")
        #expect(retrieved == settings)
    }

    @Test func codableReturnsNilWhenMissing() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        let retrieved: Settings? = sut.codable(forKey: "missing")
        #expect(retrieved == nil)
    }

    @Test func setCodableNilRemovesValue() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        let settings = Settings(theme: "light", fontSize: 12)
        sut.setCodable(settings, forKey: "s")
        sut.setCodable(nil as Settings?, forKey: "s")

        let retrieved: Settings? = sut.codable(forKey: "s")
        #expect(retrieved == nil)
        #expect(defaults.object(forKey: "s") == nil)
    }

    // MARK: - Cache behavior

    @Test func codableValueIsCached() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        let settings = Settings(theme: "dark", fontSize: 14)
        sut.setCodable(settings, forKey: "s")
        sut.resetStatistics()

        let _: Settings? = sut.codable(forKey: "s") // should be cache hit
        #expect(sut.statistics.hits == 1)
        #expect(sut.statistics.misses == 0)
    }

    @Test func codableSkipsDuplicateWrite() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        let settings = Settings(theme: "dark", fontSize: 14)
        sut.setCodable(settings, forKey: "s")
        sut.resetStatistics()

        sut.setCodable(settings, forKey: "s") // same encoded data → skip
        #expect(sut.statistics.skippedWrites == 1)
    }

    // MARK: - Array of Codable

    @Test func codableArrayRoundTrip() {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        let items = [
            Settings(theme: "dark", fontSize: 14),
            Settings(theme: "light", fontSize: 16),
        ]
        sut.setCodable(items, forKey: "items")

        let retrieved: [Settings]? = sut.codable(forKey: "items")
        #expect(retrieved == items)
    }
}
