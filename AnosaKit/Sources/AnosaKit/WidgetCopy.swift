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

    /// Watch のコンプリケーション用（`WatchComplicationContent` が使う）。iPhone の文言とは別に調整する。
    public enum Watch {
        /// 近くにあるとき、rectangular に余白があれば添える一言。
        public static let nearbyCaption = "近くにあるよ"

        /// inline に場所名を入れる上限（Character 単位）。超えたら名前を出さない。
        public static let inlineNameLimit = 8

        /// 近くにない（遠い・全部もう行った）とき。inline・rectangular 共通。corner はラベルを出さない。
        public static let noNearbyPlaces = "また思い出すね"

        /// 「行きたい」が 0 件のとき。rectangular / inline / corner。
        public static let noSavedPlaces = "場所を保存すると、ここで思い出せるよ"
        public static let noSavedPlacesShort = "場所を保存してね"
        public static let noSavedPlacesCorner = "保存してね"

        /// 現在地がまだ届いていないとき。rectangular / inline / corner。
        public static let locationUnavailable = "現在地がわかったら教えるね"
        public static let locationUnavailableShort = "現在地を待ってるよ"
        public static let locationUnavailableCorner = "現在地待ち"

        /// accessoryInline 用の 1 行。名前が `inlineNameLimit` 以下なら「<名前>・徒歩<n>分」（通知の body と同じ形）、
        /// 長ければ切り詰めずに名前を捨てて「行きたい場所まで徒歩<n>分」。
        public static func inline(placeName: String, walkingMinutes: Int) -> String {
            guard placeName.count <= inlineNameLimit else {
                return "行きたい場所まで徒歩\(walkingMinutes)分"
            }
            return NotificationCopy.body(placeName: placeName, walkingMinutes: walkingMinutes)
        }
    }
}
