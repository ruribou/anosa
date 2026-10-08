import Foundation

/// 一覧の 1 行に出す文言。名前・住所に加えて、保存からの期間と（あれば）スナップショットの距離・徒歩分を控えめに添える。
public struct PlaceRowDetail: Hashable, Sendable {
    public var name: String
    public var address: String?
    /// 例: 「3週間前に保存」
    public var savedAgoText: String
    /// 例: 「650m・徒歩8分」。「行きたい」でスナップショットに同じ場所があるときだけ。
    public var distanceText: String?
    /// VoiceOver 用の距離。例: 「650メートル、徒歩8分」
    public var spokenDistanceText: String?

    /// スナップショットは「行きたい」の近い数件だけなので、載っていない場所や「行った」「アーカイブ」では距離を出さない。
    public init(place: Place, snapshot: LocationSnapshot?, now: Date, calendar: Calendar = .current) {
        name = place.name
        address = place.address
        savedAgoText = SavedAgoText.format(savedAt: place.savedAt, now: now, calendar: calendar)
        let nearby = place.status == .wantToGo ? snapshot?.places.first { $0.id == place.id } : nil
        if let nearby {
            let walking = WidgetCopy.walking(minutes: nearby.walkingMinutes)
            distanceText = "\(DistanceText.format(meters: nearby.distanceMeters))・\(walking)"
            spokenDistanceText = "\(DistanceText.spoken(meters: nearby.distanceMeters))、\(walking)"
        } else {
            distanceText = nil
            spokenDistanceText = nil
        }
    }

    /// 行全体を 1 要素として読み上げる文。例: 「東京タワー、東京都港区…、3週間前に保存、650メートル、徒歩8分」
    public var accessibilityLabel: String {
        [name, address, savedAgoText, spokenDistanceText]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: "、")
    }
}
