import Foundation

/// iPhone と Watch の間で WatchConnectivity に載せる辞書のキーと種類。値は property list 型だけを使う。
public enum WatchSyncKey {
    public static let kind = "kind"
    public static let snapshot = "snapshot"
    public static let generatedAt = "generatedAt"
    public static let placeID = "placeID"
    public static let visitedAt = "visitedAt"

    public static let snapshotKind = "snapshot"
    public static let visitedKind = "visited"
}

/// iPhone → Watch。applicationContext と、コンプリケーション用の userInfo の両方に同じ辞書を使う。
public struct WatchSyncContext: Hashable, Sendable {
    public var snapshot: LocationSnapshot
    /// iPhone で辞書を作った時刻。Watch 側の「もう行った」の照合に使う。
    public var generatedAt: Date

    public init(snapshot: LocationSnapshot, generatedAt: Date) {
        self.snapshot = snapshot
        self.generatedAt = generatedAt
    }

    /// `kind: "snapshot"`、`snapshot`: LocationSnapshot の JSON（Data）、`generatedAt`: Date。
    public func applicationContext() throws -> [String: Any] {
        [
            WatchSyncKey.kind: WatchSyncKey.snapshotKind,
            WatchSyncKey.snapshot: try JSONEncoder().encode(snapshot),
            WatchSyncKey.generatedAt: generatedAt,
        ]
    }

    /// 種類が違う・キーがない・型が違う・JSON が読めないときは nil。
    public init?(applicationContext: [String: Any]) {
        guard
            applicationContext[WatchSyncKey.kind] as? String == WatchSyncKey.snapshotKind,
            let data = applicationContext[WatchSyncKey.snapshot] as? Data,
            let generatedAt = applicationContext[WatchSyncKey.generatedAt] as? Date,
            let snapshot = try? JSONDecoder().decode(LocationSnapshot.self, from: data)
        else { return nil }
        self.init(snapshot: snapshot, generatedAt: generatedAt)
    }

    /// 最後に取り込んだ generatedAt がこれより未来にあれば、iPhone の時計が戻ったとみなして信用しない。
    public static let futureTolerance: TimeInterval = 10 * 60

    /// Watch が届いた辞書を取り込むか。applicationContext とコンプリケーション用 userInfo の到着順は保証されないため、
    /// 最後に取り込んだもの以前（同時刻を含む）は捨てる。
    /// ただし `lastAccepted` が `now` から `futureTolerance` を超えて未来にあるときは信用せず取り込む（ちょうど許容幅は信用する）。
    public static func shouldAccept(generatedAt: Date, lastAccepted: Date?, now: Date) -> Bool {
        guard let lastAccepted else { return true }
        if lastAccepted.timeIntervalSince(now) > futureTolerance { return true }
        return generatedAt > lastAccepted
    }
}

/// Watch → iPhone の「もう行った」。transferUserInfo で送る。
public struct WatchVisitedMessage: Hashable, Sendable {
    public var placeID: UUID
    public var visitedAt: Date

    public init(placeID: UUID, visitedAt: Date) {
        self.placeID = placeID
        self.visitedAt = visitedAt
    }

    /// `kind: "visited"`、`placeID`: UUID 文字列、`visitedAt`: Date。
    public func userInfo() -> [String: Any] {
        [
            WatchSyncKey.kind: WatchSyncKey.visitedKind,
            WatchSyncKey.placeID: placeID.uuidString,
            WatchSyncKey.visitedAt: visitedAt,
        ]
    }

    /// 種類が違う・キーがない・型が違う・UUID として読めないときは nil。
    public init?(userInfo: [String: Any]) {
        guard
            userInfo[WatchSyncKey.kind] as? String == WatchSyncKey.visitedKind,
            let idString = userInfo[WatchSyncKey.placeID] as? String,
            let placeID = UUID(uuidString: idString),
            let visitedAt = userInfo[WatchSyncKey.visitedAt] as? Date
        else { return nil }
        self.init(placeID: placeID, visitedAt: visitedAt)
    }
}

extension LocationSnapshot {
    /// 同じ現在地・取得時刻のまま、`places` から作り直す（Watch の「もう行った」を反映したあとに使う）。
    public func refreshed(
        places: [Place],
        settings: AnosaSettings = .default,
        limit: Int = LocationSnapshot.defaultLimit
    ) -> LocationSnapshot {
        LocationSnapshot.make(location: location, capturedAt: capturedAt, places: places, settings: settings, limit: limit)
    }
}
