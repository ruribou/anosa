import Foundation
import Testing
@testable import AnosaKit

@Suite("判断エンジン: ステータス")
struct StatusTests {
    @Test func 行きたい以外は対象外() {
        #expect(Fixtures.decide(places: [Fixtures.place(metersNorth: 0, status: .visited)]) == nil)
        #expect(Fixtures.decide(places: [Fixtures.place(metersNorth: 0, status: .archived)]) == nil)
    }

    @Test func 近くの行った場所より遠くの行きたい場所を選ぶ() {
        let visited = Fixtures.place(metersNorth: 10, status: .visited)
        let wanted = Fixtures.place(metersNorth: 400, status: .wantToGo)
        #expect(Fixtures.decide(places: [visited, wanted])?.place.id == wanted.id)
    }

    @Test func 場所がなければnil() {
        #expect(Fixtures.decide(places: []) == nil)
    }
}

@Suite("判断エンジン: クールダウン")
struct CooldownTests {
    @Test func lastNotifiedAtから7日未満は対象外() {
        let place = Fixtures.place(lastNotifiedAt: Fixtures.now.addingTimeInterval(-7 * Fixtures.day + 1))
        #expect(Fixtures.decide(places: [place]) == nil)
    }

    @Test func lastNotifiedAtから7日経過で対象() {
        let place = Fixtures.place(lastNotifiedAt: Fixtures.now.addingTimeInterval(-7 * Fixtures.day))
        #expect(Fixtures.decide(places: [place])?.place.id == place.id)
    }

    @Test func 履歴だけに記録があってもクールダウンする() {
        let place = Fixtures.place()
        let history = [NotificationRecord(placeID: place.id, notifiedAt: Fixtures.now.addingTimeInterval(-6 * Fixtures.day))]
        #expect(Fixtures.decide(places: [place], history: history) == nil)
    }

    @Test func 履歴が古くてもlastNotifiedAtが新しければ対象外() {
        let place = Fixtures.place(lastNotifiedAt: Fixtures.now.addingTimeInterval(-1 * Fixtures.day))
        let history = [NotificationRecord(placeID: place.id, notifiedAt: Fixtures.now.addingTimeInterval(-30 * Fixtures.day))]
        #expect(Fixtures.decide(places: [place], history: history) == nil)
    }

    @Test func 同じ場所の履歴が複数あれば最新を使う() {
        let place = Fixtures.place()
        let history = [
            NotificationRecord(placeID: place.id, notifiedAt: Fixtures.now.addingTimeInterval(-2 * Fixtures.day)),
            NotificationRecord(placeID: place.id, notifiedAt: Fixtures.now.addingTimeInterval(-20 * Fixtures.day)),
        ]
        #expect(Fixtures.decide(places: [place], history: history) == nil)
    }

    @Test func 履歴が7日以上前なら対象() {
        let place = Fixtures.place()
        let history = [NotificationRecord(placeID: place.id, notifiedAt: Fixtures.now.addingTimeInterval(-8 * Fixtures.day))]
        #expect(Fixtures.decide(places: [place], history: history)?.place.id == place.id)
    }

    @Test func 他の場所のクールダウンは影響しない() {
        let cooling = Fixtures.place(metersNorth: 10, lastNotifiedAt: Fixtures.now.addingTimeInterval(-1 * Fixtures.day))
        let fresh = Fixtures.place(metersNorth: 400)
        #expect(Fixtures.decide(places: [cooling, fresh])?.place.id == fresh.id)
    }
}

@Suite("判断エンジン: 1日の上限")
struct DailyLimitTests {
    private func records(_ dates: [Date]) -> [NotificationRecord] {
        dates.map { NotificationRecord(placeID: UUID(), notifiedAt: $0) }
    }

    @Test func 当日2件でnil() {
        let history = records([Fixtures.date(2026, 10, 8, 8, 30), Fixtures.date(2026, 10, 8, 11, 0)])
        #expect(Fixtures.decide(places: [Fixtures.place()], history: history) == nil)
    }

    @Test func 当日1件なら対象() {
        let history = records([Fixtures.date(2026, 10, 8, 8, 30)])
        #expect(Fixtures.decide(places: [Fixtures.place()], history: history) != nil)
    }

    @Test func 前日分は数えない() {
        let history = records([Fixtures.date(2026, 10, 7, 21, 0), Fixtures.date(2026, 10, 7, 23, 59)])
        #expect(Fixtures.decide(places: [Fixtures.place()], history: history) != nil)
    }

    @Test func 上限の設定を変えると判定が変わる() {
        var settings = AnosaSettings.default
        settings.dailyNotificationLimit = 3
        let history = records([Fixtures.date(2026, 10, 8, 8, 30), Fixtures.date(2026, 10, 8, 11, 0)])
        #expect(Fixtures.decide(places: [Fixtures.place()], history: history, settings: settings) != nil)
    }

    @Test func 日の区切りは注入したカレンダーのタイムゾーンで判定する() {
        // 10/8 08:30 JST と 10/8 09:30 JST は JST では同じ日、UTC では 10/7 と 10/8 で別の日
        var settings = AnosaSettings.default
        settings.quietHours = QuietHours(start: TimeOfDay(hour: 0), end: TimeOfDay(hour: 0))
        let history = records([Fixtures.date(2026, 10, 8, 8, 30), Fixtures.date(2026, 10, 8, 8, 40)])
        let now = Fixtures.date(2026, 10, 8, 9, 30)
        let place = Fixtures.place()
        #expect(Fixtures.decide(places: [place], history: history, now: now, settings: settings, calendar: Fixtures.tokyo) == nil)
        #expect(Fixtures.decide(places: [place], history: history, now: now, settings: settings, calendar: Fixtures.utc) != nil)
    }
}

@Suite("判断エンジン: 静音時間")
struct QuietHoursTests {
    @Test(arguments: [
        (21, 59, true),
        (22, 0, false),
        (23, 30, false),
        (0, 0, false),
        (3, 0, false),
        (7, 59, false),
        (8, 0, true),
    ])
    func 既定の22時から8時は通知しない(hour: Int, minute: Int, notifies: Bool) {
        let now = Fixtures.date(2026, 10, 8, hour, minute)
        let place = Fixtures.place(savedAt: now.addingTimeInterval(-Fixtures.day))
        #expect((Fixtures.decide(places: [place], now: now) != nil) == notifies)
    }

    @Test func 静音判定はカレンダーのタイムゾーンで行う() {
        // 13:00 UTC = 22:00 JST
        let now = Fixtures.date(2026, 10, 8, 13, 0, calendar: Fixtures.utc)
        let place = Fixtures.place(savedAt: now.addingTimeInterval(-Fixtures.day))
        #expect(Fixtures.decide(places: [place], now: now, calendar: Fixtures.tokyo) == nil)
        #expect(Fixtures.decide(places: [place], now: now, calendar: Fixtures.utc) != nil)
    }

    @Test func 開始と終了が同じなら静音なし() {
        let quiet = QuietHours(start: TimeOfDay(hour: 22), end: TimeOfDay(hour: 22))
        #expect(!quiet.isEnabled)
        #expect(!quiet.contains(TimeOfDay(hour: 22)))
        #expect(!quiet.contains(TimeOfDay(hour: 3)))
    }

    @Test func 日跨ぎしない時間帯は開始を含み終了を含まない() {
        let quiet = QuietHours(start: TimeOfDay(hour: 13), end: TimeOfDay(hour: 14, minute: 30))
        #expect(!quiet.contains(TimeOfDay(hour: 12, minute: 59)))
        #expect(quiet.contains(TimeOfDay(hour: 13)))
        #expect(quiet.contains(TimeOfDay(hour: 14, minute: 29)))
        #expect(!quiet.contains(TimeOfDay(hour: 14, minute: 30)))
        #expect(!quiet.contains(TimeOfDay(hour: 23)))
    }

    @Test func 日跨ぎの時間帯は深夜0時をまたいで含む() {
        let quiet = AnosaSettings.default.quietHours
        #expect(quiet.contains(TimeOfDay(hour: 23, minute: 59)))
        #expect(quiet.contains(TimeOfDay(hour: 0)))
        #expect(!quiet.contains(TimeOfDay(hour: 12)))
    }
}

@Suite("判断エンジン: スヌーズ")
struct SnoozeTests {
    @Test func snoozedUntilより前は対象外() {
        let place = Fixtures.place(snoozedUntil: Fixtures.now.addingTimeInterval(1))
        #expect(Fixtures.decide(places: [place]) == nil)
    }

    @Test func snoozedUntilちょうどと過ぎた後は対象() {
        #expect(Fixtures.decide(places: [Fixtures.place(snoozedUntil: Fixtures.now)]) != nil)
        #expect(Fixtures.decide(places: [Fixtures.place(snoozedUntil: Fixtures.now.addingTimeInterval(-60))]) != nil)
    }

    @Test(arguments: [
        (Fixtures.date(2026, 10, 8, 12, 0), Fixtures.date(2026, 10, 9, 8, 0)),
        (Fixtures.date(2026, 10, 8, 23, 0), Fixtures.date(2026, 10, 9, 8, 0)),
        (Fixtures.date(2026, 10, 8, 7, 0), Fixtures.date(2026, 10, 8, 8, 0)),
        (Fixtures.date(2026, 10, 8, 8, 0), Fixtures.date(2026, 10, 9, 8, 0)),
    ])
    func 今日はやめるは次の静音明けまで(now: Date, expected: Date) {
        #expect(AnosaSettings.default.snoozeEnd(for: .today, now: now, calendar: Fixtures.tokyo) == expected)
    }

    @Test func 静音なしの設定で今日はやめるは翌日0時まで() {
        var settings = AnosaSettings.default
        settings.quietHours = QuietHours(start: TimeOfDay(hour: 0), end: TimeOfDay(hour: 0))
        let end = settings.snoozeEnd(for: .today, now: Fixtures.date(2026, 10, 8, 12, 0), calendar: Fixtures.tokyo)
        #expect(end == Fixtures.date(2026, 10, 9, 0, 0))
    }

    @Test func あとでは既定3時間() {
        let end = AnosaSettings.default.snoozeEnd(for: .later, now: Fixtures.now, calendar: Fixtures.tokyo)
        #expect(end == Fixtures.date(2026, 10, 8, 15, 0))
    }
}

@Suite("判断エンジン: 優先度")
struct PriorityTests {
    private let idA = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
    private let idB = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!

    @Test func 同じ距離なら保存が古い方() {
        let newer = Fixtures.place(id: idA, metersNorth: 200, savedAt: Fixtures.now.addingTimeInterval(-1 * Fixtures.day))
        let older = Fixtures.place(id: idB, metersNorth: 200, savedAt: Fixtures.now.addingTimeInterval(-10 * Fixtures.day))
        #expect(Fixtures.decide(places: [newer, older])?.place.id == idB)
        #expect(Fixtures.decide(places: [older, newer])?.place.id == idB)
    }

    @Test func 同じ保存日時なら近い方() {
        let near = Fixtures.place(id: idB, metersNorth: 100)
        let far = Fixtures.place(id: idA, metersNorth: 300)
        #expect(Fixtures.decide(places: [far, near])?.place.id == idB)
        #expect(Fixtures.decide(places: [near, far])?.place.id == idB)
    }

    @Test func 経過の寄与は30日で頭打ち() {
        // 頭打ちがなければ365日前の方がボーナスで大きく勝つが、頭打ちにより両者のボーナスは同じ（150m）になり近い方が勝つ
        let veryOld = Fixtures.place(id: idA, metersNorth: 300, savedAt: Fixtures.now.addingTimeInterval(-365 * Fixtures.day))
        let month = Fixtures.place(id: idB, metersNorth: 290, savedAt: Fixtures.now.addingTimeInterval(-30 * Fixtures.day))
        #expect(Fixtures.decide(places: [veryOld, month])?.place.id == idB)
        #expect(Fixtures.decide(places: [month, veryOld])?.place.id == idB)
    }

    @Test func 古さは少しだけ優先し近さを大きく覆さない() {
        // 30日分のボーナスは150m。新しい100mに対し、古い300mは負ける
        let newNear = Fixtures.place(id: idA, metersNorth: 100, savedAt: Fixtures.now)
        let oldFar = Fixtures.place(id: idB, metersNorth: 300, savedAt: Fixtures.now.addingTimeInterval(-30 * Fixtures.day))
        #expect(Fixtures.decide(places: [newNear, oldFar])?.place.id == idA)
        #expect(Fixtures.decide(places: [oldFar, newNear])?.place.id == idA)
    }

    @Test func 距離差がボーナス以内なら古い方が勝つ() {
        // 新しい100m（スコア100）と 30日前の200m（スコア50）
        let newNear = Fixtures.place(id: idA, metersNorth: 100, savedAt: Fixtures.now)
        let oldFar = Fixtures.place(id: idB, metersNorth: 200, savedAt: Fixtures.now.addingTimeInterval(-30 * Fixtures.day))
        #expect(Fixtures.decide(places: [newNear, oldFar])?.place.id == idB)
        #expect(Fixtures.decide(places: [oldFar, newNear])?.place.id == idB)
    }

    @Test func スコア式() {
        let settings = AnosaSettings.default
        let now = Fixtures.now
        #expect(DecisionEngine.priorityScore(distanceMeters: 200, savedAt: now, now: now, settings: settings) == 200)
        #expect(abs(DecisionEngine.priorityScore(distanceMeters: 200, savedAt: now.addingTimeInterval(-10 * Fixtures.day), now: now, settings: settings) - 150) < 1e-9)
        #expect(abs(DecisionEngine.priorityScore(distanceMeters: 200, savedAt: now.addingTimeInterval(-100 * Fixtures.day), now: now, settings: settings) - 50) < 1e-9)
        // 未来の保存日時はボーナスなし
        #expect(DecisionEngine.priorityScore(distanceMeters: 200, savedAt: now.addingTimeInterval(Fixtures.day), now: now, settings: settings) == 200)
    }

    @Test func 完全に同点ならidで安定して選ぶ() {
        let a = Fixtures.place(id: idA, metersNorth: 200)
        let b = Fixtures.place(id: idB, metersNorth: 200)
        #expect(Fixtures.decide(places: [a, b])?.place.id == idA)
        #expect(Fixtures.decide(places: [b, a])?.place.id == idA)
    }
}

@Suite("判断エンジン: 営業時間")
struct EngineOpeningHoursTests {
    private struct ClosedProvider: OpeningHoursProvider {
        let closed: Set<UUID>
        func isOpen(_ place: Place, at date: Date) -> Bool { !closed.contains(place.id) }
    }

    @Test func 営業中でない場所は除外して次を選ぶ() {
        let near = Fixtures.place(metersNorth: 10)
        let far = Fixtures.place(metersNorth: 400)
        let provider = ClosedProvider(closed: [near.id])
        #expect(Fixtures.decide(places: [near, far], openingHours: provider)?.place.id == far.id)
        #expect(Fixtures.decide(places: [near], openingHours: provider) == nil)
    }

    @Test func ユーザー入力の営業時間外ならnil() {
        // 2026-10-08 は木曜（weekday 5）
        let hours = OpeningHours(periods: [OpeningPeriod(weekday: 5, open: TimeOfDay(hour: 17), close: TimeOfDay(hour: 23))])
        let place = Fixtures.place(openingHours: hours)
        let provider = UserInputOpeningHoursProvider(calendar: Fixtures.tokyo)
        #expect(Fixtures.decide(places: [place], openingHours: provider) == nil)
        #expect(Fixtures.decide(places: [place], now: Fixtures.date(2026, 10, 8, 18, 0), openingHours: provider) != nil)
    }
}
