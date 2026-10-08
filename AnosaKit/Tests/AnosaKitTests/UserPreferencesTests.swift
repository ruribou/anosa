import Foundation
import Testing
@testable import AnosaKit

@Suite("利用者の設定")
struct UserPreferencesTests {
    private func preferences(limit: Int = 2, start: TimeOfDay = TimeOfDay(hour: 22), end: TimeOfDay = TimeOfDay(hour: 8), radius: Double = 500) -> UserPreferences {
        UserPreferences(dailyNotificationLimit: limit, quietHours: QuietHours(start: start, end: end), notificationRadiusMeters: radius)
    }

    @Test func 既定値は判断エンジンの既定と同じ() {
        let preferences = UserPreferences.default
        #expect(preferences.dailyNotificationLimit == 2)
        #expect(preferences.quietHours == QuietHours(start: TimeOfDay(hour: 22), end: TimeOfDay(hour: 8)))
        #expect(preferences.notificationRadiusMeters == 500)
        #expect(preferences.applied(to: .default) == .default)
    }

    @Test func 既定値は選択肢に含まれる() {
        #expect(UserPreferences.dailyNotificationLimitOptions == [1, 2, 3])
        #expect(UserPreferences.notificationRadiusOptions == [300, 500, 1000])
        #expect(UserPreferences.quietHourOptions == Array(0..<24))
        #expect(UserPreferences.default.normalized() == .default)
    }

    @Test func 反映すると3項目とリージョン半径だけが変わる() {
        let quiet = QuietHours(start: TimeOfDay(hour: 23), end: TimeOfDay(hour: 7))
        let applied = preferences(limit: 3, start: quiet.start, end: quiet.end, radius: 1000).applied(to: .default)

        #expect(applied.dailyNotificationLimit == 3)
        #expect(applied.quietHours == quiet)
        #expect(applied.notificationRadiusMeters == 1000)
        #expect(applied.regionRadiusMeters == 1000)

        var expected = AnosaSettings.default
        expected.dailyNotificationLimit = 3
        expected.quietHours = quiet
        expected.notificationRadiusMeters = 1000
        expected.regionRadiusMeters = 1000
        #expect(applied == expected)
    }

    @Test func 反映しても元の設定の他の項目は残る() {
        var base = AnosaSettings.default
        base.cooldown = 123
        base.walkingSpeedMetersPerMinute = 60
        base.monitoredRegionLimit = 10
        base.regionRadiusMeters = 800
        let applied = preferences(radius: 300).applied(to: base)
        #expect(applied.cooldown == 123)
        #expect(applied.walkingSpeedMetersPerMinute == 60)
        #expect(applied.monitoredRegionLimit == 10)
        #expect(applied.regionRadiusMeters == 300)
    }

    @Test(arguments: [
        (0, 1), (-5, 1), (1, 1), (2, 2), (3, 3), (4, 3), (100, 3),
    ])
    func 通知上限は最も近い選択肢に寄せる(input: Int, expected: Int) {
        #expect(preferences(limit: input).normalized().dailyNotificationLimit == expected)
    }

    @Test(arguments: [
        (0.0, 300.0), (-100, 300), (300, 300), (390, 300), (410, 500),
        (500, 500), (740, 500), (760, 1000), (1000, 1000), (5000, 1000),
    ])
    func 通知距離は最も近い選択肢に寄せる(input: Double, expected: Double) {
        #expect(preferences(radius: input).normalized().notificationRadiusMeters == expected)
    }

    @Test func 二つの選択肢から同じ近さなら小さい方に寄せる() {
        #expect(preferences(radius: 400).normalized().notificationRadiusMeters == 300)
        #expect(preferences(radius: 750).normalized().notificationRadiusMeters == 500)
    }

    @Test(arguments: [Double.nan, .infinity, -.infinity])
    func 有限でない通知距離は既定に戻す(input: Double) {
        #expect(preferences(radius: input).normalized().notificationRadiusMeters == 500)
    }

    @Test func 静音の時と分は範囲内ならそのまま() {
        let start = TimeOfDay(hour: 0, minute: 0)
        let end = TimeOfDay(hour: 23, minute: 59)
        #expect(preferences(start: start, end: end).normalized().quietHours == QuietHours(start: start, end: end))
    }

    @Test func 静音の開始と終了が同じなら静音なしのまま残す() {
        let same = TimeOfDay(hour: 9)
        let normalized = preferences(start: same, end: same).normalized()
        #expect(normalized.quietHours == QuietHours(start: same, end: same))
        #expect(!normalized.applied(to: .default).quietHours.isEnabled)
    }

    @Test func 静音の時と分が範囲外なら既定の同じ項目に戻す() {
        let normalized = preferences(
            start: TimeOfDay(hour: 24, minute: 30),
            end: TimeOfDay(hour: 6, minute: 60)
        ).normalized()
        #expect(normalized.quietHours.start == TimeOfDay(hour: 22, minute: 30))
        #expect(normalized.quietHours.end == TimeOfDay(hour: 6, minute: 0))

        let negative = preferences(start: TimeOfDay(hour: -1, minute: -1), end: TimeOfDay(hour: 7)).normalized()
        #expect(negative.quietHours.start == TimeOfDay(hour: 22, minute: 0))
        #expect(negative.quietHours.end == TimeOfDay(hour: 7))
    }
}

@Suite("利用者の設定の保存")
struct UserPreferencesStoreTests {
    let temporary = TemporaryDefaults()
    var store: UserPreferencesStore { UserPreferencesStore(defaults: temporary.defaults) }

    @Test func 保存キーの既定() {
        #expect(UserPreferencesStore.defaultKey == "userPreferences")
        #expect(store.key == "userPreferences")
    }

    @Test func 保存していなければ既定() {
        #expect(store.load() == .default)
        #expect(store.settings() == .default)
    }

    @Test func 保存して読み出せる() throws {
        let preferences = UserPreferences(
            dailyNotificationLimit: 1,
            quietHours: QuietHours(start: TimeOfDay(hour: 21), end: TimeOfDay(hour: 9)),
            notificationRadiusMeters: 1000
        )
        try store.save(preferences)
        #expect(UserPreferencesStore(defaults: temporary.defaults).load() == preferences)
    }

    @Test func 保存するときに正規化する() throws {
        try store.save(UserPreferences(
            dailyNotificationLimit: 9,
            quietHours: QuietHours(start: TimeOfDay(hour: 30), end: TimeOfDay(hour: 8)),
            notificationRadiusMeters: 400
        ))
        let data = try #require(temporary.defaults.data(forKey: UserPreferencesStore.defaultKey))
        let raw = try JSONDecoder().decode(UserPreferences.self, from: data)
        #expect(raw == UserPreferences(
            dailyNotificationLimit: 3,
            quietHours: QuietHours(start: TimeOfDay(hour: 22), end: TimeOfDay(hour: 8)),
            notificationRadiusMeters: 300
        ))
    }

    @Test func 読み込むときに正規化する() throws {
        let raw = UserPreferences(
            dailyNotificationLimit: 0,
            quietHours: QuietHours(start: TimeOfDay(hour: 22), end: TimeOfDay(hour: 25)),
            notificationRadiusMeters: 2000
        )
        temporary.defaults.set(try JSONEncoder().encode(raw), forKey: UserPreferencesStore.defaultKey)
        #expect(store.load() == UserPreferences(
            dailyNotificationLimit: 1,
            quietHours: QuietHours(start: TimeOfDay(hour: 22), end: TimeOfDay(hour: 8)),
            notificationRadiusMeters: 1000
        ))
    }

    @Test func 読めないデータは既定() {
        temporary.defaults.set(Data("壊れたデータ".utf8), forKey: UserPreferencesStore.defaultKey)
        #expect(store.load() == .default)
        temporary.defaults.set(Data("{\"dailyNotificationLimit\":1}".utf8), forKey: UserPreferencesStore.defaultKey)
        #expect(store.load() == .default)
    }

    @Test func 保存した設定を判断エンジンの設定に反映する() throws {
        try store.save(UserPreferences(
            dailyNotificationLimit: 3,
            quietHours: QuietHours(start: TimeOfDay(hour: 0), end: TimeOfDay(hour: 0)),
            notificationRadiusMeters: 300
        ))
        var base = AnosaSettings.default
        base.cooldown = 42
        let settings = store.settings(base: base)
        #expect(settings.dailyNotificationLimit == 3)
        #expect(!settings.quietHours.isEnabled)
        #expect(settings.notificationRadiusMeters == 300)
        #expect(settings.regionRadiusMeters == 300)
        #expect(settings.cooldown == 42)
    }
}
