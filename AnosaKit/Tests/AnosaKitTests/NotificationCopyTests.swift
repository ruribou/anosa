import Foundation
import Testing
@testable import AnosaKit

@Suite("通知文言")
struct NotificationCopyTests {
    @Test func bodyは場所名と徒歩分数() {
        #expect(NotificationCopy.body(placeName: "東京駅", walkingMinutes: 3) == "東京駅・徒歩3分")
    }

    @Test func 候補からbodyを作る() throws {
        let place = Fixtures.place(name: "テスト喫茶", metersNorth: 250)
        let candidate = try #require(Fixtures.decide(places: [place]))
        #expect(NotificationCopy.body(for: candidate) == "テスト喫茶・徒歩4分")
    }

    @Test func titleは3から5種類で重複なし_アプリ名を含まない() {
        let titles = NotificationCopy.titles
        #expect((3...5).contains(titles.count))
        #expect(Set(titles).count == titles.count)
        #expect(titles.allSatisfy { !$0.isEmpty && !$0.localizedCaseInsensitiveContains("Anosa") })
    }

    @Test func titleは注入した乱数でバリエーション内から選ばれ全種類が出る() {
        var generator = SeededGenerator(seed: 42)
        var seen = Set<String>()
        for _ in 0..<200 {
            let title = NotificationCopy.title(using: &generator)
            #expect(NotificationCopy.titles.contains(title))
            seen.insert(title)
        }
        #expect(seen == Set(NotificationCopy.titles))
    }

    @Test func 同じシードなら同じtitle列() {
        var g1 = SeededGenerator(seed: 7)
        var g2 = SeededGenerator(seed: 7)
        let a = (0..<10).map { _ in NotificationCopy.title(using: &g1) }
        let b = (0..<10).map { _ in NotificationCopy.title(using: &g2) }
        #expect(a == b)
    }

    @Test func アクション文言() {
        #expect(NotificationCopy.actionGo == "行ってみる")
        #expect(NotificationCopy.actionDismissToday == "今日はやめる")
        #expect(NotificationCopy.actionVisited == "もう行った")
    }
}

@Suite("モデル")
struct ModelTests {
    @Test func 既定の設定値() {
        let s = AnosaSettings.default
        #expect(s.notificationRadiusMeters == 500)
        #expect(s.dailyNotificationLimit == 2)
        #expect(s.cooldown == 7 * Fixtures.day)
        #expect(s.quietHours == QuietHours(start: TimeOfDay(hour: 22), end: TimeOfDay(hour: 8)))
        #expect(s.walkingSpeedMetersPerMinute == 80)
    }

    @Test func PlaceとSettingsはCodableで往復できる() throws {
        let place = Place(
            name: "テスト",
            latitude: 35.681236,
            longitude: 139.767125,
            address: "東京都千代田区",
            sourceURL: URL(string: "https://example.com/place"),
            note: "メモ",
            savedAt: Fixtures.now,
            status: .visited,
            lastNotifiedAt: Fixtures.now,
            snoozedUntil: Fixtures.now,
            notifiedCount: 3,
            openingHours: OpeningHours(periods: [OpeningPeriod(weekday: 2, open: TimeOfDay(hour: 9), close: TimeOfDay(hour: 18))])
        )
        let decodedPlace = try JSONDecoder().decode(Place.self, from: JSONEncoder().encode(place))
        #expect(decodedPlace == place)
        let decodedSettings = try JSONDecoder().decode(AnosaSettings.self, from: JSONEncoder().encode(AnosaSettings.default))
        #expect(decodedSettings == .default)
    }
}
