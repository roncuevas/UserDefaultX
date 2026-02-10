import Testing
import Foundation
@testable import UserDefaultX

@Suite("Property Wrapper Tests")
struct DefaultXTests {

    private let suiteName = "com.userdefaultx.wrapper.\(UUID().uuidString)"

    private func makeStore() -> (UserDefaultX, UserDefaults) {
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = UserDefaultX(defaults: defaults)
        return (store, defaults)
    }

    private func cleanup(_ defaults: UserDefaults) {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - @DefaultX

    @Test func defaultXReturnsDefaultWhenMissing() {
        let (store, defaults) = makeStore()
        defer { cleanup(defaults) }

        @DefaultX("name", store: store) var name = "Guest"
        #expect(name == "Guest")
    }

    @Test func defaultXPersistsValue() {
        let (store, defaults) = makeStore()
        defer { cleanup(defaults) }

        @DefaultX("name", store: store) var name = "Guest"
        name = "Alice"
        #expect(name == "Alice")
        #expect(store.string(forKey: "name") == "Alice")
    }

    @Test func defaultXReadsExistingValue() {
        let (store, defaults) = makeStore()
        defer { cleanup(defaults) }

        store.set("Bob", forKey: "name")
        @DefaultX("name", store: store) var name = "Guest"
        #expect(name == "Bob")
    }

    @Test func defaultXWithInteger() {
        let (store, defaults) = makeStore()
        defer { cleanup(defaults) }

        @DefaultX("count", store: store) var count = 0
        count = 42
        #expect(count == 42)
    }

    @Test func defaultXWithBool() {
        let (store, defaults) = makeStore()
        defer { cleanup(defaults) }

        @DefaultX("enabled", store: store) var enabled = false
        enabled = true
        #expect(enabled == true)
    }

    // MARK: - @DefaultXCodable

    struct Theme: Codable, Sendable, Equatable {
        var name: String
        var isDark: Bool
    }

    @Test func defaultXCodableReturnsDefaultWhenMissing() {
        let (store, defaults) = makeStore()
        defer { cleanup(defaults) }

        let fallback = Theme(name: "Default", isDark: false)
        @DefaultXCodable("theme", store: store) var theme = fallback
        #expect(theme == fallback)
    }

    @Test func defaultXCodablePersistsAndReads() {
        let (store, defaults) = makeStore()
        defer { cleanup(defaults) }

        let fallback = Theme(name: "Default", isDark: false)
        @DefaultXCodable("theme", store: store) var theme = fallback

        let dark = Theme(name: "Dark", isDark: true)
        theme = dark
        #expect(theme == dark)

        // Verify via a fresh wrapper pointing to the same store/key
        @DefaultXCodable("theme", store: store) var theme2 = fallback
        #expect(theme2 == dark)
    }
}
