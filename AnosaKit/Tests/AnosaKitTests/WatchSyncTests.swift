import Foundation
import Testing
@testable import AnosaKit

@Suite("Watch 同期のペイロード")
struct WatchSyncTests {
    static func snapshot() -> LocationSnapshot {
        LocationSnapshot.make(
            location: Fixtures.origin,
            capturedAt: Fixtures.now,
            places: [Fixtures.place(name: "喫茶店", metersNorth: 200), Fixtures.place(name: "本屋", metersNorth: 600)]
        )
    }

    @Test func スナップショットを辞書にして戻せる() throws {
        let context = WatchSyncContext(snapshot: Self.snapshot(), generatedAt: Fixtures.now.addingTimeInterval(5))
        let dictionary = try context.applicationContext()
        #expect(dictionary["kind"] as? String == "snapshot")
        #expect(dictionary["snapshot"] is Data)
        #expect(dictionary["generatedAt"] as? Date == Fixtures.now.addingTimeInterval(5))
        #expect(WatchSyncContext(applicationContext: dictionary) == context)
    }

    @Test func 辞書はproperty_listとして書き出せる() throws {
        let context = WatchSyncContext(snapshot: Self.snapshot(), generatedAt: Fixtures.now)
        #expect(PropertyListSerialization.propertyList(try context.applicationContext(), isValidFor: .binary))
        let message = WatchVisitedMessage(placeID: UUID(), visitedAt: Fixtures.now)
        #expect(PropertyListSerialization.propertyList(message.userInfo(), isValidFor: .binary))
    }

    @Test func 場所が空のスナップショットも戻せる() throws {
        let empty = LocationSnapshot(location: Fixtures.origin, capturedAt: Fixtures.now, places: [])
        let context = WatchSyncContext(snapshot: empty, generatedAt: Fixtures.now)
        #expect(WatchSyncContext(applicationContext: try context.applicationContext()) == context)
    }

    @Test func スナップショットの辞書が不正ならnil() throws {
        let valid = try WatchSyncContext(snapshot: Self.snapshot(), generatedAt: Fixtures.now).applicationContext()
        #expect(WatchSyncContext(applicationContext: [:]) == nil)

        for key in ["kind", "snapshot", "generatedAt"] {
            var missing = valid
            missing[key] = nil
            #expect(WatchSyncContext(applicationContext: missing) == nil, "\(key) がない")
        }

        var wrongKind = valid
        wrongKind["kind"] = "visited"
        #expect(WatchSyncContext(applicationContext: wrongKind) == nil)

        var brokenJSON = valid
        brokenJSON["snapshot"] = Data("壊れたデータ".utf8)
        #expect(WatchSyncContext(applicationContext: brokenJSON) == nil)

        var snapshotAsString = valid
        snapshotAsString["snapshot"] = "{}"
        #expect(WatchSyncContext(applicationContext: snapshotAsString) == nil)

        var dateAsNumber = valid
        dateAsNumber["generatedAt"] = Fixtures.now.timeIntervalSince1970
        #expect(WatchSyncContext(applicationContext: dateAsNumber) == nil)
    }

    @Test func もう行ったを辞書にして戻せる() {
        let id = UUID()
        let message = WatchVisitedMessage(placeID: id, visitedAt: Fixtures.now)
        let dictionary = message.userInfo()
        #expect(dictionary["kind"] as? String == "visited")
        #expect(dictionary["placeID"] as? String == id.uuidString)
        #expect(dictionary["visitedAt"] as? Date == Fixtures.now)
        #expect(WatchVisitedMessage(userInfo: dictionary) == message)
    }

    @Test func もう行ったの辞書が不正ならnil() throws {
        let valid = WatchVisitedMessage(placeID: UUID(), visitedAt: Fixtures.now).userInfo()
        #expect(WatchVisitedMessage(userInfo: [:]) == nil)

        for key in ["kind", "placeID", "visitedAt"] {
            var missing = valid
            missing[key] = nil
            #expect(WatchVisitedMessage(userInfo: missing) == nil, "\(key) がない")
        }

        var wrongKind = valid
        wrongKind["kind"] = "snapshot"
        #expect(WatchVisitedMessage(userInfo: wrongKind) == nil)

        var notUUID = valid
        notUUID["placeID"] = "place-1"
        #expect(WatchVisitedMessage(userInfo: notUUID) == nil)

        var idAsUUID = valid
        idAsUUID["placeID"] = UUID()
        #expect(WatchVisitedMessage(userInfo: idAsUUID) == nil)

        var dateAsString = valid
        dateAsString["visitedAt"] = "2026-10-08"
        #expect(WatchVisitedMessage(userInfo: dateAsString) == nil)
    }

    @Test func 種類の違う辞書を取り違えない() throws {
        let context = try WatchSyncContext(snapshot: Self.snapshot(), generatedAt: Fixtures.now).applicationContext()
        let visited = WatchVisitedMessage(placeID: UUID(), visitedAt: Fixtures.now).userInfo()
        #expect(WatchVisitedMessage(userInfo: context) == nil)
        #expect(WatchSyncContext(applicationContext: visited) == nil)
    }

    @Test func もう行ったを反映して同じ現在地と時刻で作り直す() {
        let near = Fixtures.place(name: "近い", metersNorth: 100)
        let middle = Fixtures.place(name: "中くらい", metersNorth: 300)
        let far = Fixtures.place(name: "遠い", metersNorth: 900)
        let location = Fixtures.north(meters: 0)
        let original = LocationSnapshot.make(location: location, capturedAt: Fixtures.now, places: [near, middle, far], limit: 2)
        #expect(original.places.map(\.id) == [near.id, middle.id])

        var visitedNear = near
        visitedNear.status = .visited
        let refreshed = original.refreshed(places: [visitedNear, middle, far], limit: 2)

        #expect(refreshed.location == original.location)
        #expect(refreshed.capturedAt == Fixtures.now)
        #expect(refreshed.places.map(\.id) == [middle.id, far.id])
    }

    @Test func 最初の辞書は取り込む() {
        #expect(WatchSyncContext.shouldAccept(generatedAt: Fixtures.now, lastAccepted: nil, now: Fixtures.now))
    }

    @Test func 最後に取り込んだものより新しい辞書だけ取り込む() {
        let last = Fixtures.now
        let now = Fixtures.now.addingTimeInterval(60)
        #expect(WatchSyncContext.shouldAccept(generatedAt: last.addingTimeInterval(1), lastAccepted: last, now: now))
        #expect(!WatchSyncContext.shouldAccept(generatedAt: last, lastAccepted: last, now: now))
        #expect(!WatchSyncContext.shouldAccept(generatedAt: last.addingTimeInterval(-1), lastAccepted: last, now: now))
    }

    @Test func 許容幅ちょうど未来の最後の時刻は信用する() {
        let last = Fixtures.now.addingTimeInterval(WatchSyncContext.futureTolerance)
        #expect(WatchSyncContext.futureTolerance == 600)
        #expect(!WatchSyncContext.shouldAccept(generatedAt: Fixtures.now, lastAccepted: last, now: Fixtures.now))
        #expect(!WatchSyncContext.shouldAccept(generatedAt: last, lastAccepted: last, now: Fixtures.now))
        #expect(WatchSyncContext.shouldAccept(generatedAt: last.addingTimeInterval(1), lastAccepted: last, now: Fixtures.now))
    }

    @Test func 許容幅を超えて未来の最後の時刻は信用せず古い辞書も取り込む() {
        let last = Fixtures.now.addingTimeInterval(WatchSyncContext.futureTolerance + 1)
        #expect(WatchSyncContext.shouldAccept(generatedAt: Fixtures.now, lastAccepted: last, now: Fixtures.now))
        #expect(WatchSyncContext.shouldAccept(generatedAt: Fixtures.now.addingTimeInterval(-3600), lastAccepted: last, now: Fixtures.now))
    }

    @Test func 作り直しは既定で5件まで() {
        let places = (1...7).map { Fixtures.place(metersNorth: Double($0) * 100) }
        let original = LocationSnapshot(location: Fixtures.origin, capturedAt: Fixtures.now, places: [])
        #expect(original.refreshed(places: places).places.map(\.id) == places.prefix(5).map(\.id))
    }
}
