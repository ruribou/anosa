import Foundation

/// ウィジェットに出す内容。`LocationSnapshot` から作る純粋な値。
public enum NearestPlaceDisplay: Hashable, Sendable {
    /// スナップショットがまだない（位置が未取得・未許可）。
    case locationUnavailable
    /// スナップショットはあるが、近くに「行きたい」場所がない。
    case noNearbyPlaces
    case nearest(NearestPlaceSummary)

    /// スナップショットの古さでは表示を変えない（位置は大きく動いたときに更新されるため、古くても現在地とずれているとは限らない）。
    public init(snapshot: LocationSnapshot?) {
        guard let snapshot else {
            self = .locationUnavailable
            return
        }
        guard let place = snapshot.places.first else {
            self = .noNearbyPlaces
            return
        }
        self = .nearest(NearestPlaceSummary(place))
    }

    /// 空の状態の案内文。場所があるときは nil。
    public var message: String? {
        switch self {
        case .locationUnavailable: WidgetCopy.locationUnavailable
        case .noNearbyPlaces: WidgetCopy.noNearbyPlaces
        case .nearest: nil
        }
    }

    /// accessoryInline 用の 1 行。
    public var inlineText: String {
        switch self {
        case .locationUnavailable: WidgetCopy.locationUnavailableShort
        case .noNearbyPlaces: WidgetCopy.noNearbyPlacesShort
        case .nearest(let summary): WidgetCopy.inline(placeName: summary.name, distance: summary.distanceText)
        }
    }
}

public struct NearestPlaceSummary: Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var distanceMeters: Double
    /// 例: 「350m」「1.2km」
    public var distanceText: String
    /// 例: 「徒歩5分」
    public var walkingText: String

    public init(_ place: NearbyPlace) {
        id = place.id
        name = place.name
        distanceMeters = place.distanceMeters
        distanceText = DistanceText.format(meters: place.distanceMeters)
        walkingText = WidgetCopy.walking(minutes: place.walkingMinutes)
    }
}

/// ロケールに依存しない距離の表示。
public enum DistanceText {
    /// 地球上の 2 点間の距離より十分大きい上限（100,000km）。
    public static let maximumMeters: Double = 100_000_000

    /// 10m 単位に四捨五入して 1000m 未満なら「350m」、それ以外は 0.1km 単位に四捨五入して「1.2km」。
    /// 負の値・NaN は 0m、`maximumMeters` を超える値（無限大を含む）は `maximumMeters` として扱う（Int への変換で落ちないため）。
    public static func format(meters: Double) -> String {
        let meters = meters.isNaN ? 0 : min(max(0, meters), maximumMeters)
        let tens = (meters / 10).rounded()
        if tens < 100 {
            return "\(Int(tens) * 10)m"
        }
        let tenths = Int((meters / 100).rounded())
        return "\(tenths / 10).\(tenths % 10)km"
    }
}
