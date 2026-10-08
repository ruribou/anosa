import Foundation

/// 通知の文言。調整はこのファイルだけで行う。
/// 見出しにはアプリ名「Anosa」が自動表示される前提で、title にアプリ名を入れない。
public enum NotificationCopy {
    public static let titles: [String] = [
        "近くにあるよ",
        "ちょっと寄れそう",
        "そういえば、ここ",
        "いま行けそうだよ",
    ]

    public static let actionGo = "行ってみる"
    public static let actionDismissToday = "今日はやめる"
    public static let actionVisited = "もう行った"

    public static func title<G: RandomNumberGenerator>(using generator: inout G) -> String {
        titles.randomElement(using: &generator) ?? titles[0]
    }

    public static func title() -> String {
        var generator = SystemRandomNumberGenerator()
        return title(using: &generator)
    }

    public static func body(placeName: String, walkingMinutes: Int) -> String {
        "\(placeName)・徒歩\(walkingMinutes)分"
    }

    public static func body(for candidate: NotificationCandidate) -> String {
        body(placeName: candidate.place.name, walkingMinutes: candidate.walkingMinutes)
    }
}
