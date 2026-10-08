import Foundation
import Testing
@testable import AnosaKit

@Suite("通知履歴の保存")
struct NotificationHistoryStoreTests {
    let temporary = TemporaryDefaults()
    var store: NotificationHistoryStore { NotificationHistoryStore(defaults: temporary.defaults) }

    @Test func 何も保存していなければ空() {
        #expect(store.records().isEmpty)
    }

    @Test func 追記した順に読み出せる() throws {
        let first = NotificationRecord(placeID: UUID(), notifiedAt: Fixtures.now.addingTimeInterval(-3600))
        let second = NotificationRecord(placeID: UUID(), notifiedAt: Fixtures.now)
        try store.append(first, now: first.notifiedAt)
        try store.append(second, now: second.notifiedAt)
        #expect(store.records() == [first, second])
        #expect(NotificationHistoryStore(defaults: temporary.defaults).records() == [first, second])
    }

    @Test func 保持期間より古い記録を追記時に刈る() throws {
        let retention = NotificationHistoryStore.retention(settings: .default)
        #expect(retention == 8 * Fixtures.day)

        let tooOld = NotificationRecord(placeID: UUID(), notifiedAt: Fixtures.now.addingTimeInterval(-retention - 1))
        let boundary = NotificationRecord(placeID: UUID(), notifiedAt: Fixtures.now.addingTimeInterval(-retention))
        try store.append(tooOld, now: tooOld.notifiedAt)
        try store.append(boundary, now: boundary.notifiedAt)
        #expect(store.records().count == 2)

        let latest = NotificationRecord(placeID: UUID(), notifiedAt: Fixtures.now)
        try store.append(latest, now: Fixtures.now)
        #expect(store.records() == [boundary, latest])
    }

    @Test func 保持期間はクールダウンが短くても1日上限の判定に足りる() {
        var settings = AnosaSettings.default
        settings.cooldown = 0
        #expect(NotificationHistoryStore.retention(settings: settings) == 2 * Fixtures.day)
    }

    @Test func 読めないデータは空として扱い追記で上書きする() throws {
        temporary.defaults.set(Data("壊れたデータ".utf8), forKey: NotificationHistoryStore.defaultKey)
        #expect(store.records().isEmpty)
        let record = NotificationRecord(placeID: UUID(), notifiedAt: Fixtures.now)
        try store.append(record, now: Fixtures.now)
        #expect(store.records() == [record])
    }
}
