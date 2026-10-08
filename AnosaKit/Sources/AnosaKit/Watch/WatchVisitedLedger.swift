import Foundation

/// Watch で「もう行った」を押したが、iPhone からのスナップショットにまだ反映されていない場所。
public struct WatchVisitedLedger: Hashable, Codable, Sendable {
    public var visits: [UUID: Date]
    /// iPhone への送信をキューに積んだ記録（`visits` にある id だけを持つ）。
    public private(set) var sent: Set<UUID>

    public init(visits: [UUID: Date] = [:], sent: Set<UUID> = []) {
        self.visits = visits
        self.sent = sent.intersection(visits.keys)
    }

    private enum CodingKeys: String, CodingKey {
        case visits
        case sent
    }

    /// `sent` がない保存データ（送信済みの印を持つ前の形式）は、すべて未送信として読む。
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            visits: try container.decode([UUID: Date].self, forKey: .visits),
            sent: try container.decodeIfPresent(Set<UUID>.self, forKey: .sent) ?? []
        )
    }

    /// 反映を待つ上限。iPhone に届かなかった記録を残し続けないため。
    public static let expiry: TimeInterval = 24 * 60 * 60

    /// 押し直したときも時刻を更新し、未送信に戻す。
    public mutating func markVisited(_ id: UUID, at date: Date) {
        visits[id] = date
        sent.remove(id)
    }

    /// iPhone にまだ送っていない記録。押した時刻の順（同時刻は id の順）。
    public var unsentMessages: [WatchVisitedMessage] {
        visits
            .filter { !sent.contains($0.key) }
            .map { WatchVisitedMessage(placeID: $0.key, visitedAt: $0.value) }
            .sorted { ($0.visitedAt, $0.placeID.uuidString) < ($1.visitedAt, $1.placeID.uuidString) }
    }

    /// 送信をキューに積んだ記録に印を付ける。台帳の記録と時刻が違う（その後押し直された・もうない）ときは何もしない。
    public mutating func markSent(_ message: WatchVisitedMessage) {
        guard visits[message.placeID] == message.visitedAt else { return }
        sent.insert(message.placeID)
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
        return WatchVisitedLedger(visits: kept, sent: sent)
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
