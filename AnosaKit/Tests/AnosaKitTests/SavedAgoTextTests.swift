import Foundation
import Testing
@testable import AnosaKit

@Suite("一覧の行: 保存からの期間")
struct SavedAgoTextTests {
    private func text(_ savedAt: Date, now: Date = Fixtures.now, calendar: Calendar = Fixtures.tokyo) -> String {
        SavedAgoText.format(savedAt: savedAt, now: now, calendar: calendar)
    }

    @Test func 同じ日は今日保存() {
        #expect(text(Fixtures.date(2026, 10, 8, 0, 0)) == "今日保存")
        #expect(text(Fixtures.now) == "今日保存")
    }

    @Test func 未来の日時は今日保存() {
        #expect(text(Fixtures.now.addingTimeInterval(60 * 60)) == "今日保存")
        #expect(text(Fixtures.date(2026, 10, 11, 9, 0)) == "今日保存")
    }

    @Test func 前日は時刻によらず昨日保存() {
        #expect(text(Fixtures.date(2026, 10, 7, 23, 59)) == "昨日保存")
        #expect(text(Fixtures.date(2026, 10, 7, 0, 0)) == "昨日保存")
    }

    @Test func 二日前から六日前は日数() {
        #expect(text(Fixtures.date(2026, 10, 6, 12, 0)) == "2日前に保存")
        #expect(text(Fixtures.date(2026, 10, 2, 0, 0)) == "6日前に保存")
    }

    @Test func 週は日数を7で割って切り捨て() {
        #expect(text(Fixtures.date(2026, 9, 25, 12, 0)) == "1週間前に保存")
        #expect(text(Fixtures.date(2026, 9, 24, 12, 0)) == "2週間前に保存")
    }

    @Test func 日と週の境界は7日() {
        #expect(text(Fixtures.date(2026, 10, 2, 12, 0)) == "6日前に保存")
        #expect(text(Fixtures.date(2026, 10, 1, 12, 0)) == "1週間前に保存")
    }

    @Test func 週と月の境界は30日() {
        // 29 日前・30 日前
        #expect(text(Fixtures.date(2026, 9, 9, 12, 0)) == "4週間前に保存")
        #expect(text(Fixtures.date(2026, 9, 8, 12, 0)) == "1か月前に保存")
    }

    @Test func 月は暦の月の差() {
        #expect(text(Fixtures.date(2026, 8, 8, 12, 0)) == "2か月前に保存")
        #expect(text(Fixtures.date(2025, 11, 8, 12, 0)) == "11か月前に保存")
    }

    @Test func 月と年の境界は12か月() {
        #expect(text(Fixtures.date(2025, 10, 9, 12, 0)) == "11か月前に保存")
        #expect(text(Fixtures.date(2025, 10, 8, 12, 0)) == "1年前に保存")
        #expect(text(Fixtures.date(2024, 10, 9, 12, 0)) == "1年前に保存")
        #expect(text(Fixtures.date(2023, 10, 8, 12, 0)) == "3年前に保存")
    }

    @Test func 日の区切りはカレンダーのタイムゾーンで決める() {
        let savedAt = Fixtures.date(2026, 10, 7, 23, 30)
        let now = Fixtures.date(2026, 10, 8, 0, 30)
        #expect(text(savedAt, now: now, calendar: Fixtures.tokyo) == "昨日保存")
        #expect(text(savedAt, now: now, calendar: Fixtures.utc) == "今日保存")
    }
}
