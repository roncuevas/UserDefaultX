import Testing
import Foundation
@testable import UserDefaultX

@Suite("Thread Safety Tests")
struct ThreadSafetyTests {

    private let suiteName = "com.userdefaultx.thread.\(UUID().uuidString)"

    private func makeSUT() -> (UserDefaultX, UserDefaults) {
        let defaults = UserDefaults(suiteName: suiteName)!
        let sut = UserDefaultX(defaults: defaults)
        return (sut, defaults)
    }

    private func cleanup(_ defaults: UserDefaults) {
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func concurrentWritesDoNotCrash() async {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    sut.set("value-\(i)", forKey: "key-\(i % 10)")
                }
            }
        }

        // If we reach here without crashing, the test passes
        #expect(true)
    }

    @Test func concurrentReadsDoNotCrash() async {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        for i in 0..<10 {
            sut.set("value-\(i)", forKey: "key-\(i)")
        }

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    _ = sut.string(forKey: "key-\(i % 10)")
                }
            }
        }

        #expect(true)
    }

    @Test func concurrentReadWriteMix() async {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    if i.isMultiple(of: 2) {
                        sut.set("val-\(i)", forKey: "shared")
                    } else {
                        _ = sut.string(forKey: "shared")
                    }
                }
            }
        }

        #expect(true)
    }

    @Test func concurrentInvalidation() async {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    switch i % 3 {
                    case 0: sut.set("v-\(i)", forKey: "k")
                    case 1: _ = sut.string(forKey: "k")
                    default: sut.invalidateCache()
                    }
                }
            }
        }

        #expect(true)
    }

    @Test func concurrentStatisticsAccess() async {
        let (sut, defaults) = makeSUT()
        defer { cleanup(defaults) }

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    if i.isMultiple(of: 3) {
                        _ = sut.statistics
                    } else {
                        sut.set(i, forKey: "k-\(i % 5)")
                    }
                }
            }
        }

        #expect(true)
    }
}
