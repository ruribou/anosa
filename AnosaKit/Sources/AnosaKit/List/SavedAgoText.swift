import Foundation

/// 一覧の行に出す「保存してからの期間」。日付の絶対表記は使わず、ざっくりした言い方にする。
public enum SavedAgoText {
    public static let today = "今日保存"
    public static let yesterday = "昨日保存"

    /// 日の数え方は `calendar` の日付（0 時区切り）。未来の日時（時計のずれ等）は「今日保存」。
    /// - 0 日: 今日保存 / 1 日: 昨日保存 / 2〜6 日: n日前に保存
    /// - 7〜29 日: n週間前に保存（日数 ÷ 7 の切り捨て、1〜4）
    /// - 30 日以上で 12 か月未満: nか月前に保存（暦の月の差、最小 1）
    /// - 12 か月以上: n年前に保存（月の差 ÷ 12 の切り捨て）
    public static func format(savedAt: Date, now: Date, calendar: Calendar = .current) -> String {
        let savedDay = calendar.startOfDay(for: savedAt)
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: savedDay, to: today).day ?? 0
        switch days {
        case ..<1:
            return Self.today
        case 1:
            return yesterday
        case 2..<7:
            return "\(days)日前に保存"
        case 7..<30:
            return "\(days / 7)週間前に保存"
        default:
            let months = max(1, calendar.dateComponents([.month], from: savedDay, to: today).month ?? 1)
            if months < 12 {
                return "\(months)か月前に保存"
            }
            return "\(months / 12)年前に保存"
        }
    }
}
