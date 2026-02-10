# UserDefaultX

An in-memory **write-through / read-through cache** layer over `UserDefaults` for Swift. Reduces redundant disk I/O by caching values in memory and skipping writes when the value hasn't changed.

## Features

- **Read-through cache** — First read goes to `UserDefaults`, subsequent reads come from memory.
- **Write-through cache** — Writes update cache + disk. Redundant writes (same value) are skipped entirely.
- **Thread-safe** — All cache access is protected with `Synchronization.Mutex`. No data races.
- **Nil sentinel** — Distinguishes "not cached" from "cached as nil" using `NSNull`, avoiding repeated disk lookups for missing keys.
- **External change detection** — Observes `UserDefaults.didChangeNotification` to automatically invalidate the cache when another process or subsystem modifies defaults directly.
- **Codable support** — Encode/decode any `Codable & Sendable` type via JSON, stored as raw `Data` in cache.
- **Property wrappers** — `@DefaultX` for standard plist types, `@DefaultXCodable` for custom Codable types.
- **Diagnostics** — `CacheStatistics` with hits, misses, skippedWrites, and computed hitRate.

## Requirements

| Platform | Minimum Version |
|----------|----------------|
| iOS | 18.0 |
| macOS | 15.0 |
| tvOS | 18.0 |
| watchOS | 11.0 |
| visionOS | 2.0 |
| Swift | 6.2+ |

> These minimums are required by `Synchronization.Mutex`.

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/roncuevas/UserDefaultX.git", from: "1.0.0")
]
```

Then add `"UserDefaultX"` to your target's dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: ["UserDefaultX"]
)
```

## Usage

### Basic read/write

```swift
import UserDefaultX

let defaults = UserDefaultX.standard

// Write (caches + persists to disk)
defaults.set("Alice", forKey: "username")
defaults.set(42, forKey: "score")
defaults.set(true, forKey: "isPremium")

// Read (served from cache on subsequent calls)
let name = defaults.string(forKey: "username")   // "Alice"
let score = defaults.integer(forKey: "score")     // 42
let premium = defaults.bool(forKey: "isPremium")  // true
```

### Redundant write skipping

```swift
defaults.set("Alice", forKey: "username") // writes to disk
defaults.set("Alice", forKey: "username") // skipped — value unchanged
defaults.set("Bob", forKey: "username")   // writes to disk — value changed
```

### Codable types

```swift
struct AppSettings: Codable, Sendable {
    var theme: String
    var fontSize: Int
}

let settings = AppSettings(theme: "dark", fontSize: 14)

// Write
defaults.setCodable(settings, forKey: "settings")

// Read
let loaded: AppSettings? = defaults.codable(forKey: "settings")
```

### Property wrappers

```swift
// Standard plist types
@DefaultX("username")
var username: String = "Guest"

@DefaultX("launchCount")
var launchCount: Int = 0

// Codable types
@DefaultXCodable("settings")
var settings: AppSettings = AppSettings(theme: "light", fontSize: 12)
```

Use a custom store:

```swift
let store = UserDefaultX(defaults: UserDefaults(suiteName: "group.myapp")!)

@DefaultX("token", store: store)
var token: String = ""
```

### Cache management

```swift
// Invalidate a single key (forces re-read from disk on next access)
defaults.invalidateCache(forKey: "username")

// Invalidate the entire cache
defaults.invalidateCache()

// Remove a key from cache and disk
defaults.removeObject(forKey: "username")

// Check if a key exists in UserDefaults
defaults.hasValue(forKey: "username") // Bool
```

### Diagnostics

```swift
let stats = defaults.statistics

print("Hits: \(stats.hits)")
print("Misses: \(stats.misses)")
print("Skipped writes: \(stats.skippedWrites)")
print("Hit rate: \(stats.hitRate)") // 0.0 to 1.0

defaults.resetStatistics()
```

## Architecture

```
@DefaultX / @DefaultXCodable      Property Wrappers
         |
    UserDefaultX                   Read-through / Write-through cache
         |
    CacheStore                     Dictionary protected with Mutex
         |
    UserDefaults                   Persistent storage (disk)
```

| Component | Responsibility |
|-----------|---------------|
| `CacheStore` | Thread-safe `Dictionary` with `Mutex`, `NSNull` sentinel, `NSObject.isEqual` comparison |
| `UserDefaultX` | Public API, read-through/write-through logic, `didChangeNotification` observer |
| `CacheStatistics` | Diagnostic counters (hits, misses, skippedWrites, hitRate) |
| `@DefaultX` | Property wrapper for standard plist types (`String`, `Int`, `Bool`, etc.) |
| `@DefaultXCodable` | Property wrapper for `Codable & Sendable` types |

## License

MIT
