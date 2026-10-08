import Foundation

/// ユーザーが任意入力する営業時間。
public struct OpeningHours: Hashable, Codable, Sendable {
    public var periods: [OpeningPeriod]

    public init(periods: [OpeningPeriod]) {
        self.periods = periods
    }

    /// `periods` が空のときは未設定とみなし、営業中扱いにする。
    public func isOpen(at date: Date, calendar: Calendar) -> Bool {
        guard !periods.isEmpty else { return true }
        let weekday = calendar.component(.weekday, from: date)
        let time = TimeOfDay(of: date, calendar: calendar)
        return periods.contains { $0.contains(weekday: weekday, time: time) }
    }
}

/// 1つの営業時間帯。`weekday` は `Calendar` と同じ 1=日曜 … 7=土曜。
/// `open` を含み `close` を含まない。`close < open` は翌日への日跨ぎ、`open == close` はその曜日の終日営業。
public struct OpeningPeriod: Hashable, Codable, Sendable {
    public var weekday: Int
    public var open: TimeOfDay
    public var close: TimeOfDay

    public init(weekday: Int, open: TimeOfDay, close: TimeOfDay) {
        self.weekday = weekday
        self.open = open
        self.close = close
    }

    func contains(weekday day: Int, time: TimeOfDay) -> Bool {
        if open == close { return day == weekday }
        if open < close { return day == weekday && open <= time && time < close }
        let nextWeekday = weekday % 7 + 1
        return (day == weekday && time >= open) || (day == nextWeekday && time < close)
    }
}

public protocol OpeningHoursProvider: Sendable {
    func isOpen(_ place: Place, at date: Date) -> Bool
}

/// 常に営業中とみなす実装。
public struct AlwaysOpenProvider: OpeningHoursProvider {
    public init() {}

    public func isOpen(_ place: Place, at date: Date) -> Bool { true }
}

/// ユーザー入力の営業時間で判定する実装。未設定の場所は営業中扱い。
public struct UserInputOpeningHoursProvider: OpeningHoursProvider {
    public var calendar: Calendar

    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    public func isOpen(_ place: Place, at date: Date) -> Bool {
        guard let openingHours = place.openingHours else { return true }
        return openingHours.isOpen(at: date, calendar: calendar)
    }
}
