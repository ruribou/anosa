import Foundation

/// コンプリケーション・Smart Stack に出す内容。文言の調整はこのファイルで行う。
public struct WatchComplicationContent: Hashable, Sendable {
    /// いちばん近い表示対象の場所。なければ nil。
    public var place: NearbyPlace?
    /// Smart Stack の relevance。0〜1。
    public var relevance: Double

    public static let emptyMessage = "近くの行きたい場所はまだないよ"
    public static let emptyInlineMessage = "近くにはまだないよ"

    public init(place: NearbyPlace?, settings: AnosaSettings = .default) {
        self.place = place
        self.relevance = Self.relevance(for: place, settings: settings)
    }

    /// スナップショットがなければ場所なし。台帳にある場所は除く。
    public init(snapshot: LocationSnapshot?, ledger: WatchVisitedLedger, settings: AnosaSettings = .default) {
        let place = snapshot.flatMap { ledger.visiblePlaces(in: $0, limit: 1).first }
        self.init(place: place, settings: settings)
    }

    /// accessoryInline 用。「<名前>・徒歩<n>分」（通知の body と同じ形）。
    public var inlineText: String {
        guard let place else { return Self.emptyInlineMessage }
        return NotificationCopy.body(placeName: place.name, walkingMinutes: place.walkingMinutes)
    }

    /// 「徒歩<n>分」。場所がなければ nil。
    public var walkingText: String? {
        place.map { "徒歩\($0.walkingMinutes)分" }
    }

    /// 距離の表示（iOS ウィジェットと同じ `DistanceText.format`）。場所がなければ nil。
    public var distanceText: String? {
        place.map { DistanceText.format(meters: $0.distanceMeters) }
    }

    /// 場所なし → 0、通知の半径以内 → 1.0 − 0.5 × 距離/半径（0.5〜1.0）、それより遠い → 0.1。
    public static func relevance(for place: NearbyPlace?, settings: AnosaSettings) -> Double {
        guard let place else { return 0 }
        let distance = max(0, place.distanceMeters)
        let radius = settings.notificationRadiusMeters
        guard distance <= radius else { return 0.1 }
        guard radius > 0 else { return 1.0 }
        return 1.0 - 0.5 * distance / radius
    }
}
