import Foundation

/// Watch で「もう行った」を押したが、iPhone からのスナップショットにまだ反映されていない場所。
public struct WatchVisitedLedger: Hashable, Codable, Sendable {
    public var visits: [UUID: Date]

    public init(visits: [UUID: Date] = [:]) {
        self.visits = visits
    }

    /// 反映を待つ上限。iPhone に届かなかった記録を残し続けないため。
    public static let expiry: TimeInterval = 24 * 60 * 60

    public mutating func markVisited(_ id: UUID, at date: Date) {
        visits[id] = date
    }

    /// 台帳にある場所を除いて、近い順に `limit` 件。
    public func visiblePlaces(in snapshot: LocationSnapshot, limit: Int = 3) -> [NearbyPlace] {
        guard limit > 0 else { return [] }
        return Array(snapshot.places.filter { visits[$0.id] == nil }.prefix(limit))
    }

    /// 反映済み・期限切れの記録を除く。
    /// - 反映済み: `generatedAt` が押した時刻より後で、スナップショットにその場所がない。
    /// - 期限切れ: 押してから `expiry` を超えた（ちょうどは残す）。
    public func reconciled(with context: WatchSyncContext, now: Date) -> WatchVisitedLedger {
        let listed = Set(context.snapshot.places.map(\.id))
        let kept = visits.filter { id, visitedAt in
            let reflected = context.generatedAt > visitedAt && !listed.contains(id)
            let expired = now.timeIntervalSince(visitedAt) > Self.expiry
            return !reflected && !expired
        }
        return WatchVisitedLedger(visits: kept)
    }
}

/// 台帳を App Group の UserDefaults に JSON で保存する。
public struct WatchVisitedLedgerStore {
    public static let defaultKey = "watchVisitedLedger"

    public let defaults: UserDefaults
    public let key: String

    public init(defaults: UserDefaults, key: String = defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    /// App Group の suite。取れなければ `.standard`。
    public static func shared() -> WatchVisitedLedgerStore {
        WatchVisitedLedgerStore(defaults: SharedDefaults.make())
    }

    public func save(_ ledger: WatchVisitedLedger) throws {
        defaults.set(try JSONEncoder().encode(ledger), forKey: key)
    }

    /// 保存がない・読めないときは空。
    public func load() -> WatchVisitedLedger {
        guard let data = defaults.data(forKey: key) else { return WatchVisitedLedger() }
        return (try? JSONDecoder().decode(WatchVisitedLedger.self, from: data)) ?? WatchVisitedLedger()
    }
}
