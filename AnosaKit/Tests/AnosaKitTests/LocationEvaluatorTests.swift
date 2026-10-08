import Foundation
import Testing
@testable import AnosaKit

@MainActor
@Suite("位置変化の評価と通知の記録")
struct LocationEvaluatorTests {
    let store: PlaceStore
    let temporary = TemporaryDefaults()
    let evaluator: LocationEvaluator

    init() throws {
        store = PlaceStore(container: try AnosaStore.makeContainer(inMemory: true))
        evaluator = LocationEvaluator(
            store: store,
            history: NotificationHistoryStore(defaults: temporary.defaults),
            calendar: Fixtures.tokyo
        )
    }

    @Test func 候補があればlastNotifiedAtとnotifiedCountと履歴を記録する() throws {
        let place = Fixtures.place(metersNorth: 200)
        try store.save(place)

        let candidate = try #require(try evaluator.evaluate(currentLocation: Fixtures.origin, now: Fixtures.now))

        var expected = place
        expected.lastNotifiedAt = Fixtures.now
        expected.notifiedCount = 1
        #expect(candidate.place == expected)
        #expect(candidate.walkingMinutes == 3)
        #expect(try store.place(id: place.id) == expected)
        #expect(evaluator.history.records() == [NotificationRecord(placeID: place.id, notifiedAt: Fixtures.now)])
    }

    @Test func notifiedCountは既存の値に足す() throws {
        var place = Fixtures.place(lastNotifiedAt: Fixtures.now.addingTimeInterval(-30 * Fixtures.day))
        place.notifiedCount = 4
        try store.save(place)
        _ = try evaluator.evaluate(currentLocation: Fixtures.origin, now: Fixtures.now)
        #expect(try store.place(id: place.id)?.notifiedCount == 5)
    }

    @Test func 候補がなければ何も記録しない() throws {
        let far = Fixtures.place(metersNorth: 2000)
        try store.save(far)

        #expect(try evaluator.evaluate(currentLocation: Fixtures.origin, now: Fixtures.now) == nil)
        #expect(try store.places() == [far])
        #expect(evaluator.history.records().isEmpty)
    }

    @Test func 静音時間は記録しない() throws {
        let place = Fixtures.place()
        try store.save(place)
        #expect(try evaluator.evaluate(currentLocation: Fixtures.origin, now: Fixtures.date(2026, 10, 8, 23, 0)) == nil)
        #expect(evaluator.history.records().isEmpty)
    }

    @Test func 同じ場所は記録後にクールダウンで通知しない() throws {
        let place = Fixtures.place()
        try store.save(place)
        #expect(try evaluator.evaluate(currentLocation: Fixtures.origin, now: Fixtures.now) != nil)
        #expect(try evaluator.evaluate(currentLocation: Fixtures.origin, now: Fixtures.now.addingTimeInterval(60)) == nil)
    }

    @Test func 一日上限が履歴経由で効く() throws {
        let places = (1...3).map { Fixtures.place(name: "場所\($0)", metersNorth: Double($0) * 100) }
        for place in places { try store.save(place) }

        let first = try evaluator.evaluate(currentLocation: Fixtures.origin, now: Fixtures.now)
        let second = try evaluator.evaluate(currentLocation: Fixtures.origin, now: Fixtures.now.addingTimeInterval(60))
        let third = try evaluator.evaluate(currentLocation: Fixtures.origin, now: Fixtures.now.addingTimeInterval(120))

        #expect(first?.place.id == places[0].id)
        #expect(second?.place.id == places[1].id)
        #expect(third == nil)
        #expect(evaluator.history.records().count == 2)
        #expect(try store.place(id: places[2].id)?.notifiedCount == 0)

        let nextDay = Fixtures.date(2026, 10, 9, 9, 0)
        #expect(try evaluator.evaluate(currentLocation: Fixtures.origin, now: nextDay)?.place.id == places[2].id)
    }

    @Test func 営業時間外は通知しない() throws {
        // 2026-10-08 は木曜（weekday 5）。12:00 は営業時間外。
        let place = Fixtures.place(openingHours: OpeningHours(periods: [
            OpeningPeriod(weekday: 5, open: TimeOfDay(hour: 17, minute: 0), close: TimeOfDay(hour: 22, minute: 0)),
        ]))
        try store.save(place)
        #expect(try evaluator.evaluate(currentLocation: Fixtures.origin, now: Fixtures.now) == nil)
        #expect(try evaluator.evaluate(currentLocation: Fixtures.origin, now: Fixtures.date(2026, 10, 8, 18, 0))?.place.id == place.id)
    }

    @Test func 削除済みの場所の候補は記録しない() throws {
        let candidate = NotificationCandidate(place: Fixtures.place(), distanceMeters: 100, walkingMinutes: 2)
        #expect(try evaluator.record(candidate, now: Fixtures.now) == nil)
        #expect(try store.places().isEmpty)
        #expect(evaluator.history.records().isEmpty)
    }
}
