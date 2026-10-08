import Foundation
import Testing
@testable import AnosaKit

@Suite("営業時間スタブ")
struct OpeningHoursTests {
    private let provider = UserInputOpeningHoursProvider(calendar: Fixtures.tokyo)

    private func place(_ periods: [OpeningPeriod]?) -> Place {
        Fixtures.place(openingHours: periods.map { OpeningHours(periods: $0) })
    }

    @Test func 基準日は木曜() {
        #expect(Fixtures.tokyo.component(.weekday, from: Fixtures.now) == 5)
    }

    @Test func 未設定なら常に営業中() {
        #expect(provider.isOpen(place(nil), at: Fixtures.date(2026, 10, 8, 3, 0)))
        #expect(provider.isOpen(place([]), at: Fixtures.date(2026, 10, 8, 3, 0)))
        #expect(AlwaysOpenProvider().isOpen(place([OpeningPeriod(weekday: 1, open: TimeOfDay(hour: 10), close: TimeOfDay(hour: 11))]), at: Fixtures.now))
    }

    @Test func 同日の時間帯は開店を含み閉店を含まない() {
        let p = place([OpeningPeriod(weekday: 5, open: TimeOfDay(hour: 10), close: TimeOfDay(hour: 20))])
        #expect(!provider.isOpen(p, at: Fixtures.date(2026, 10, 8, 9, 59)))
        #expect(provider.isOpen(p, at: Fixtures.date(2026, 10, 8, 10, 0)))
        #expect(provider.isOpen(p, at: Fixtures.date(2026, 10, 8, 19, 59)))
        #expect(!provider.isOpen(p, at: Fixtures.date(2026, 10, 8, 20, 0)))
    }

    @Test func 曜日が違えば閉店() {
        let p = place([OpeningPeriod(weekday: 5, open: TimeOfDay(hour: 10), close: TimeOfDay(hour: 20))])
        #expect(!provider.isOpen(p, at: Fixtures.date(2026, 10, 9, 12, 0)))
    }

    @Test func 日跨ぎの時間帯は翌日の閉店まで営業() {
        // 金曜 18:00〜翌 02:00
        let p = place([OpeningPeriod(weekday: 6, open: TimeOfDay(hour: 18), close: TimeOfDay(hour: 2))])
        #expect(!provider.isOpen(p, at: Fixtures.date(2026, 10, 9, 17, 59)))
        #expect(provider.isOpen(p, at: Fixtures.date(2026, 10, 9, 23, 0)))
        #expect(provider.isOpen(p, at: Fixtures.date(2026, 10, 10, 1, 59)))
        #expect(!provider.isOpen(p, at: Fixtures.date(2026, 10, 10, 2, 0)))
        // 同じ金曜の未明は前日（木曜）の続きではないので閉店
        #expect(!provider.isOpen(p, at: Fixtures.date(2026, 10, 9, 1, 0)))
    }

    @Test func 土曜の日跨ぎは日曜にまたがる() {
        let p = place([OpeningPeriod(weekday: 7, open: TimeOfDay(hour: 22), close: TimeOfDay(hour: 3))])
        #expect(provider.isOpen(p, at: Fixtures.date(2026, 10, 11, 1, 0)))
    }

    @Test func 開店と閉店が同じならその曜日は終日営業() {
        let p = place([OpeningPeriod(weekday: 5, open: TimeOfDay(hour: 0), close: TimeOfDay(hour: 0))])
        #expect(provider.isOpen(p, at: Fixtures.date(2026, 10, 8, 0, 0)))
        #expect(provider.isOpen(p, at: Fixtures.date(2026, 10, 8, 23, 59)))
        #expect(!provider.isOpen(p, at: Fixtures.date(2026, 10, 9, 0, 0)))
    }

    @Test func 複数の時間帯のどれかに入れば営業中() {
        let p = place([
            OpeningPeriod(weekday: 5, open: TimeOfDay(hour: 11), close: TimeOfDay(hour: 14)),
            OpeningPeriod(weekday: 5, open: TimeOfDay(hour: 17), close: TimeOfDay(hour: 22)),
        ])
        #expect(provider.isOpen(p, at: Fixtures.date(2026, 10, 8, 12, 0)))
        #expect(!provider.isOpen(p, at: Fixtures.date(2026, 10, 8, 15, 0)))
        #expect(provider.isOpen(p, at: Fixtures.date(2026, 10, 8, 18, 0)))
    }
}
