public struct CacheStatistics: Sendable, Equatable {
    public let hits: Int
    public let misses: Int
    public let skippedWrites: Int

    public var hitRate: Double {
        let total = hits + misses
        guard total > 0 else { return 0 }
        return Double(hits) / Double(total)
    }
}
