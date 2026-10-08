import Foundation

/// コンプリケーション・Smart Stack に出す内容。文言は `WidgetCopy.Watch` で調整する。
///
/// ファミリーごとに残す情報（優先順）:
/// - inline: 名前と徒歩分（名前が長ければ徒歩分だけ）→ `inlineText`
/// - circular: アイコンと徒歩分のどちらか一つ（名前は出さない）→ `place?.walkingMinutes`
/// - rectangular: 名前 → 徒歩分・距離 → 一言（近くにない等は `rectangularMessage` だけ）
/// - corner: 徒歩分か短い状態だけ → `cornerLabel`
public struct WatchComplicationContent: Hashable, Sendable {
    public enum State: Hashable, Sendable {
        /// 台帳を除いた最寄りが `notificationRadiusMeters` 以内（境界を含む）。
        case nearby(NearbyPlace)
        /// 場所はあるが、台帳を除いた最寄りが半径より遠い、または全部台帳にある。
        case noNearbyPlaces
        /// スナップショットはあるが「行きたい」が 0 件。
        case noSavedPlaces
        /// スナップショットがない（現在地が未取得・未許可）。
        case locationUnavailable
    }

    public var state: State
    /// Smart Stack の relevance。0〜1。
    public var relevance: Double

    /// Watch アプリ本体の ContentUnavailableView 用。
    public static let emptyMessage = "近くの行きたい場所はまだないよ"

    public init(state: State, relevance: Double) {
        self.state = state
        self.relevance = relevance
    }

    /// 台帳を除いた最寄りの場所から作る。半径以内なら近くにある、遠ければ近くにない（relevance 0.1）。
    public init(nearest place: NearbyPlace, settings: AnosaSettings = .default) {
        let relevance = Self.relevance(for: place, settings: settings)
        let isNearby = max(0, place.distanceMeters) <= settings.notificationRadiusMeters
        self.init(state: isNearby ? .nearby(place) : .noNearbyPlaces, relevance: relevance)
    }

    /// スナップショットなし → 現在地未取得、places が空 → 保存なし、全部台帳にある → 近くにない（relevance 0）。
    public init(snapshot: LocationSnapshot?, ledger: WatchVisitedLedger, settings: AnosaSettings = .default) {
        guard let snapshot else {
            self.init(state: .locationUnavailable, relevance: 0)
            return
        }
        guard !snapshot.places.isEmpty else {
            self.init(state: .noSavedPlaces, relevance: 0)
            return
        }
        guard let place = ledger.visiblePlaces(in: snapshot, limit: 1).first else {
            self.init(state: .noNearbyPlaces, relevance: 0)
            return
        }
        self.init(nearest: place, settings: settings)
    }

    /// 近くにあるときだけ場所を返す。近くにない状態では名前・距離を出さない。
    public var place: NearbyPlace? {
        if case .nearby(let place) = state { return place }
        return nil
    }

    /// accessoryInline 用の 1 行（全状態）。近くにあれば名前と徒歩分、名前が長ければ徒歩分を優先する。
    public var inlineText: String {
        switch state {
        case .nearby(let place):
            WidgetCopy.Watch.inline(placeName: place.name, walkingMinutes: place.walkingMinutes)
        case .noNearbyPlaces:
            WidgetCopy.Watch.noNearbyPlaces
        case .noSavedPlaces:
            WidgetCopy.Watch.noSavedPlacesShort
        case .locationUnavailable:
            WidgetCopy.Watch.locationUnavailableShort
        }
    }

    /// accessoryRectangular で近くにないときに出す一言。近くにあるときは名前を主にするので nil。
    public var rectangularMessage: String? {
        switch state {
        case .nearby:
            nil
        case .noNearbyPlaces:
            WidgetCopy.Watch.noNearbyPlaces
        case .noSavedPlaces:
            WidgetCopy.Watch.noSavedPlaces
        case .locationUnavailable:
            WidgetCopy.Watch.locationUnavailable
        }
    }

    /// accessoryCorner のラベル。時計を邪魔しないよう徒歩分か短い状態だけ。近くにないときは出さない（nil）。
    public var cornerLabel: String? {
        switch state {
        case .nearby(let place):
            WidgetCopy.walking(minutes: place.walkingMinutes)
        case .noNearbyPlaces:
            nil
        case .noSavedPlaces:
            WidgetCopy.Watch.noSavedPlacesCorner
        case .locationUnavailable:
            WidgetCopy.Watch.locationUnavailableCorner
        }
    }

    /// 「徒歩<n>分」。rectangular の副情報。近くにあるときだけ。
    public var walkingText: String? {
        place.map { WidgetCopy.walking(minutes: $0.walkingMinutes) }
    }

    /// 距離の表示（iOS ウィジェットと同じ `DistanceText.format`）。rectangular の副情報。近くにあるときだけ。
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
