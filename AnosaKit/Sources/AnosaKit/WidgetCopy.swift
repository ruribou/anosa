import Foundation

/// ウィジェットの文言。調整はこのファイルだけで行う。
/// 徒歩分は通知の body（NotificationCopy）と同じ「徒歩{n}分」にそろえる。
public enum WidgetCopy {
    /// small の見出し。
    public static let nearestHeading = "いちばん近く"

    /// 位置がまだ取れていない・許可されていないとき。
    public static let locationUnavailable = "現在地がわかったら教えるね"
    public static let locationUnavailableShort = "現在地を待ってるよ"

    /// 近くに「行きたい」場所がないとき。
    public static let noNearbyPlaces = "近くにはまだないみたい"
    public static let noNearbyPlacesShort = "近くにはないよ"

    public static func walking(minutes: Int) -> String {
        "徒歩\(minutes)分"
    }

    /// accessoryInline 用の 1 行。
    public static func inline(placeName: String, distance: String) -> String {
        "\(placeName)・\(distance)"
    }
}
