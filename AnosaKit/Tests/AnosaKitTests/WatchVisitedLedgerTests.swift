import Foundation
import Testing
@testable import AnosaKit

@Suite("Watch のもう行った台帳")
struct WatchVisitedLedgerTests {
    let places = (1...5).map { Fixtures.place(name: "場所\($0)", metersNorth: Double($0) * 100) }
    var snapshot: LocationSnapshot {
        LocationSnapshot.make(location: Fixtures.origin, capturedAt: Fixtures.now, places: places)
    }

    @Test func 台帳が空なら近い順に3件() {
        #expect(WatchVisitedLedger().visiblePlaces(in: snapshot).map(\.id) == places.prefix(3).map(\.id))
    }

    @Test func もう行った場所を除いて近い順に件数まで() {
        var ledger = WatchVisitedLedger()
        ledger.markVisited(places[0].id, at: Fixtures.now)
        ledger.markVisited(places[2].id, at: Fixtures.now)
        #expect(ledger.visiblePlaces(in: snapshot).map(\.id) == [places[1].id, places[3].id, places[4].id])
        #expect(ledger.visiblePlaces(in: snapshot, limit: 1).map(\.id) == [places[1].id])
        #expect(ledger.visiblePlaces(in: snapshot, limit: 0).isEmpty)
        #expect(ledger.visiblePlaces(in: snapshot, limit: -1).isEmpty)
    }

    @Test func 同じ場所を押し直すと時刻を更新する() {
        var ledger = WatchVisitedLedger()
        ledger.markVisited(places[0].id, at: Fixtures.now)
        ledger.markVisited(places[0].id, at: Fixtures.now.addingTimeInterval(60))
        #expect(ledger.visits == [places[0].id: Fixtures.now.addingTimeInterval(60)])
    }

    @Test func 押した後に作られてその場所がないスナップショットで消す() {
        var ledger = WatchVisitedLedger()
        ledger.markVisited(places[0].id, at: Fixtures.now)
        let without = LocationSnapshot.make(location: Fixtures.origin, capturedAt: Fixtures.now, places: Array(places.dropFirst()))
        let context = WatchSyncContext(snapshot: without, generatedAt: Fixtures.now.addingTimeInterval(1))
        #expect(ledger.reconciled(with: context, now: Fixtures.now.addingTimeInterval(1)).visits.isEmpty)
    }

    @Test func スナップショットにまだ場所があれば残す() {
        var ledger = WatchVisitedLedger()
        ledger.markVisited(places[0].id, at: Fixtures.now)
        let context = WatchSyncContext(snapshot: snapshot, generatedAt: Fixtures.now.addingTimeInterval(60))
        #expect(ledger.reconciled(with: context, now: Fixtures.now.addingTimeInterval(60)) == ledger)
    }

    @Test func 押す前か同時に作られたスナップショットでは消さない() {
        var ledger = WatchVisitedLedger()
        ledger.markVisited(places[0].id, at: Fixtures.now)
        let without = LocationSnapshot.make(location: Fixtures.origin, capturedAt: Fixtures.now, places: Array(places.dropFirst()))
        for generatedAt in [Fixtures.now.addingTimeInterval(-60), Fixtures.now] {
            let context = WatchSyncContext(snapshot: without, generatedAt: generatedAt)
            #expect(ledger.reconciled(with: context, now: Fixtures.now) == ledger)
        }
    }

    @Test func 押してから1日を超えた記録は消してちょうど1日は残す() {
        var ledger = WatchVisitedLedger()
        let boundary = places[0].id
        let tooOld = places[1].id
        ledger.markVisited(boundary, at: Fixtures.now.addingTimeInterval(-Fixtures.day))
        ledger.markVisited(tooOld, at: Fixtures.now.addingTimeInterval(-Fixtures.day - 1))
        // 古いスナップショット（どちらの記録より前）なので、反映済みによる削除は起きない。
        let context = WatchSyncContext(snapshot: snapshot, generatedAt: Fixtures.now.addingTimeInterval(-2 * Fixtures.day))
        #expect(ledger.reconciled(with: context, now: Fixtures.now).visits == [boundary: Fixtures.now.addingTimeInterval(-Fixtures.day)])
    }

    @Test func 場所ごとに別々に照合する() {
        var ledger = WatchVisitedLedger()
        ledger.markVisited(places[0].id, at: Fixtures.now)
        ledger.markVisited(places[1].id, at: Fixtures.now.addingTimeInterval(120))
        let without0 = LocationSnapshot.make(location: Fixtures.origin, capturedAt: Fixtures.now, places: Array(places.dropFirst()))
        let context = WatchSyncContext(snapshot: without0, generatedAt: Fixtures.now.addingTimeInterval(60))
        #expect(ledger.reconciled(with: context, now: Fixtures.now.addingTimeInterval(180)).visits.keys.sorted { $0.uuidString < $1.uuidString } == [places[1].id])
    }

    @Test func 保存して読み出せる() throws {
        let temporary = TemporaryDefaults()
        let store = WatchVisitedLedgerStore(defaults: temporary.defaults)
        #expect(store.load() == WatchVisitedLedger())

        var ledger = WatchVisitedLedger()
        ledger.markVisited(places[0].id, at: Fixtures.now)
        ledger.markVisited(places[1].id, at: Fixtures.now.addingTimeInterval(30))
        try store.save(ledger)
        #expect(WatchVisitedLedgerStore(defaults: temporary.defaults).load() == ledger)

        try store.save(WatchVisitedLedger())
        #expect(store.load().visits.isEmpty)
    }

    @Test func 押した記録は未送信で押した時刻の順に返す() {
        var ledger = WatchVisitedLedger()
        ledger.markVisited(places[1].id, at: Fixtures.now.addingTimeInterval(60))
        ledger.markVisited(places[0].id, at: Fixtures.now)
        #expect(ledger.unsentMessages == [
            WatchVisitedMessage(placeID: places[0].id, visitedAt: Fixtures.now),
            WatchVisitedMessage(placeID: places[1].id, visitedAt: Fixtures.now.addingTimeInterval(60)),
        ])
    }

    @Test func 送信済みの印を付けた記録は未送信に含めない() {
        var ledger = WatchVisitedLedger()
        ledger.markVisited(places[0].id, at: Fixtures.now)
        ledger.markVisited(places[1].id, at: Fixtures.now.addingTimeInterval(60))
        ledger.markSent(WatchVisitedMessage(placeID: places[0].id, visitedAt: Fixtures.now))
        #expect(ledger.sent == [places[0].id])
        #expect(ledger.unsentMessages.map(\.placeID) == [places[1].id])
        // 送信済みでも台帳には残り、一覧からは除いたまま。
        #expect(ledger.visits.count == 2)
        #expect(!ledger.visiblePlaces(in: snapshot).map(\.id).contains(places[0].id))
    }

    @Test func 時刻が違うか台帳にない記録には印を付けない() {
        var ledger = WatchVisitedLedger()
        ledger.markVisited(places[0].id, at: Fixtures.now)
        ledger.markSent(WatchVisitedMessage(placeID: places[0].id, visitedAt: Fixtures.now.addingTimeInterval(-1)))
        ledger.markSent(WatchVisitedMessage(placeID: places[1].id, visitedAt: Fixtures.now))
        #expect(ledger.sent.isEmpty)
        #expect(ledger.unsentMessages.map(\.placeID) == [places[0].id])
    }

    @Test func 押し直すと未送信に戻る() {
        var ledger = WatchVisitedLedger()
        ledger.markVisited(places[0].id, at: Fixtures.now)
        ledger.markSent(WatchVisitedMessage(placeID: places[0].id, visitedAt: Fixtures.now))
        ledger.markVisited(places[0].id, at: Fixtures.now.addingTimeInterval(60))
        #expect(ledger.unsentMessages == [WatchVisitedMessage(placeID: places[0].id, visitedAt: Fixtures.now.addingTimeInterval(60))])
    }

    @Test func 台帳にない場所の送信済みは持たない() {
        let ledger = WatchVisitedLedger(visits: [places[0].id: Fixtures.now], sent: [places[0].id, places[1].id])
        #expect(ledger.sent == [places[0].id])
    }

    @Test func 照合で残った記録は送信済みの印も残し消えた記録の印は消す() {
        var ledger = WatchVisitedLedger()
        ledger.markVisited(places[0].id, at: Fixtures.now)
        ledger.markVisited(places[1].id, at: Fixtures.now.addingTimeInterval(120))
        ledger.markSent(WatchVisitedMessage(placeID: places[0].id, visitedAt: Fixtures.now))
        ledger.markSent(WatchVisitedMessage(placeID: places[1].id, visitedAt: Fixtures.now.addingTimeInterval(120)))
        let without0 = LocationSnapshot.make(location: Fixtures.origin, capturedAt: Fixtures.now, places: Array(places.dropFirst()))
        let context = WatchSyncContext(snapshot: without0, generatedAt: Fixtures.now.addingTimeInterval(60))
        let reconciled = ledger.reconciled(with: context, now: Fixtures.now.addingTimeInterval(180))
        #expect(reconciled.sent == [places[1].id])
        #expect(reconciled.unsentMessages.isEmpty)
    }

    @Test func 送信済みの印も保存して読み出せる() throws {
        let temporary = TemporaryDefaults()
        let store = WatchVisitedLedgerStore(defaults: temporary.defaults)
        var ledger = WatchVisitedLedger()
        ledger.markVisited(places[0].id, at: Fixtures.now)
        ledger.markVisited(places[1].id, at: Fixtures.now.addingTimeInterval(30))
        ledger.markSent(WatchVisitedMessage(placeID: places[0].id, visitedAt: Fixtures.now))
        try store.save(ledger)
        let loaded = store.load()
        #expect(loaded == ledger)
        #expect(loaded.sent == [places[0].id])
    }

    @Test func 送信済みの項目がない旧形式はすべて未送信として読む() throws {
        let temporary = TemporaryDefaults()
        // 送信済みの印を持つ前の形式（visits だけ）で保存されたデータ。
        struct LegacyLedger: Encodable {
            var visits: [UUID: Date]
        }
        let visits = [places[0].id: Fixtures.now, places[1].id: Fixtures.now.addingTimeInterval(30)]
        temporary.defaults.set(try JSONEncoder().encode(LegacyLedger(visits: visits)), forKey: WatchVisitedLedgerStore.defaultKey)
        let loaded = WatchVisitedLedgerStore(defaults: temporary.defaults).load()
        #expect(loaded.visits == visits)
        #expect(loaded.sent.isEmpty)
        #expect(loaded.unsentMessages.map(\.placeID) == [places[0].id, places[1].id])
    }

    @Test func 読めないデータは空() {
        let temporary = TemporaryDefaults()
        temporary.defaults.set(Data("壊れたデータ".utf8), forKey: WatchVisitedLedgerStore.defaultKey)
        #expect(WatchVisitedLedgerStore(defaults: temporary.defaults).load() == WatchVisitedLedger())
    }
}
