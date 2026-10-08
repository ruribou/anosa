import Foundation
import Testing
@testable import AnosaKit

@Suite("位置のスナップショット")
struct LocationSnapshotTests {
    @Test func 行きたい場所だけを近い順に上限まで入れる() {
        let places = (1...7).map { Fixtures.place(name: "場所\($0)", metersNorth: Double($0) * 100) }
        let visited = Fixtures.place(metersNorth: 10, status: .visited)
        let archived = Fixtures.place(metersNorth: 20, status: .archived)

        let snapshot = LocationSnapshot.make(
            location: Fixtures.origin,
            capturedAt: Fixtures.now,
            places: (places + [visited, archived]).shuffled()
        )

        #expect(snapshot.location == Fixtures.origin)
        #expect(snapshot.capturedAt == Fixtures.now)
        #expect(snapshot.places.map(\.id) == places.prefix(5).map(\.id))
    }

    @Test func 名前と座標と距離と徒歩分が入る() throws {
        let place = Fixtures.place(name: "東京タワー", metersNorth: 450)
        let snapshot = LocationSnapshot.make(location: Fixtures.origin, capturedAt: Fixtures.now, places: [place])
        let nearby = try #require(snapshot.places.first)
        #expect(nearby.name == "東京タワー")
        #expect(nearby.coordinate == place.coordinate)
        #expect(abs(nearby.distanceMeters - 450) < 0.01)
        #expect(nearby.walkingMinutes == 6)
    }

    @Test func 上限を指定できて場所がなければ空() {
        let places = (1...3).map { Fixtures.place(metersNorth: Double($0) * 100) }
        #expect(LocationSnapshot.make(location: Fixtures.origin, capturedAt: Fixtures.now, places: places, limit: 2).places.count == 2)
        #expect(LocationSnapshot.make(location: Fixtures.origin, capturedAt: Fixtures.now, places: []).places.isEmpty)
    }

    @Test func 保存して読み出せる() throws {
        let temporary = TemporaryDefaults()
        let store = LocationSnapshotStore(defaults: temporary.defaults)
        #expect(store.load() == nil)

        let snapshot = LocationSnapshot.make(
            location: Fixtures.origin,
            capturedAt: Fixtures.now,
            places: [Fixtures.place(metersNorth: 300)]
        )
        try store.save(snapshot)
        #expect(store.load() == snapshot)

        let newer = LocationSnapshot.make(location: Fixtures.north(meters: 50), capturedAt: Fixtures.now.addingTimeInterval(60), places: [])
        try store.save(newer)
        #expect(LocationSnapshotStore(defaults: temporary.defaults).load() == newer)
    }

    @Test func 読めないデータはnil() {
        let temporary = TemporaryDefaults()
        temporary.defaults.set(Data("x".utf8), forKey: LocationSnapshotStore.defaultKey)
        #expect(LocationSnapshotStore(defaults: temporary.defaults).load() == nil)
    }
}
