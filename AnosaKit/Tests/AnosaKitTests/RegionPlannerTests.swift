import Foundation
import Testing
@testable import AnosaKit

@Suite("リージョンの入れ替え")
struct RegionPlannerTests {
    func plan(
        _ places: [Place],
        monitored: Set<String> = [],
        limit: Int = 20,
        radius: Double = 500
    ) -> RegionPlan {
        RegionPlanner.plan(
            currentLocation: Fixtures.origin,
            places: places,
            monitoredIdentifiers: monitored,
            limit: limit,
            radiusMeters: radius
        )
    }

    @Test func 近い順に並ぶ() {
        let far = Fixtures.place(name: "遠い", metersNorth: 3000)
        let near = Fixtures.place(name: "近い", metersNorth: 100)
        let middle = Fixtures.place(name: "中間", metersNorth: 800)
        let result = plan([far, near, middle])
        #expect(result.desired.map(\.placeID) == [near.id, middle.id, far.id])
        #expect(result.toAdd.map(\.placeID) == [near.id, middle.id, far.id])
    }

    @Test func 上限で切れて遠い場所が落ちる() {
        let places = (1...25).map { Fixtures.place(metersNorth: Double($0) * 100) }
        let result = plan(places.shuffled(), limit: 20)
        #expect(result.desired.count == 20)
        #expect(result.desired.map(\.placeID) == places.prefix(20).map(\.id))
    }

    @Test func 上限が0以下なら何も監視せず監視中を全部外す() {
        let place = Fixtures.place()
        let monitored: Set = [RegionIdentifier.make(for: place.id)]
        for limit in [0, -1] {
            let result = plan([place], monitored: monitored, limit: limit)
            #expect(result.desired.isEmpty)
            #expect(result.toAdd.isEmpty)
            #expect(result.toRemove == [RegionIdentifier.make(for: place.id)])
        }
    }

    @Test func 行きたい以外は監視しない() {
        let visited = Fixtures.place(metersNorth: 10, status: .visited)
        let archived = Fixtures.place(metersNorth: 20, status: .archived)
        let wanted = Fixtures.place(metersNorth: 5000)
        #expect(plan([visited, archived, wanted]).desired.map(\.placeID) == [wanted.id])
    }

    @Test func スヌーズ中やクールダウン中の場所も監視は続ける() {
        let snoozed = Fixtures.place(metersNorth: 100, snoozedUntil: Fixtures.now.addingTimeInterval(3600))
        let cooling = Fixtures.place(metersNorth: 200, lastNotifiedAt: Fixtures.now)
        #expect(plan([snoozed, cooling]).desired.map(\.placeID) == [snoozed.id, cooling.id])
    }

    @Test func 同じ距離はid昇順で決まる() {
        let a = Fixtures.place(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, metersNorth: 300)
        let b = Fixtures.place(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, metersNorth: 300)
        #expect(plan([a, b]).desired.map(\.placeID) == [b.id, a.id])
        #expect(plan([b, a]).desired.map(\.placeID) == [b.id, a.id])
        #expect(plan([a, b], limit: 1).desired.map(\.placeID) == [b.id])
    }

    @Test func 半径と中心と距離が入る() {
        let place = Fixtures.place(metersNorth: 1000)
        let region = try! #require(plan([place], radius: 300).desired.first)
        #expect(region.identifier == "place.\(place.id.uuidString)")
        #expect(region.center == place.coordinate)
        #expect(region.radiusMeters == 300)
        #expect(abs(region.distanceMeters - 1000) < 0.01)
    }

    @Test func 既に監視中なら追加しない() {
        let kept = Fixtures.place(metersNorth: 100)
        let added = Fixtures.place(metersNorth: 200)
        let result = plan([kept, added], monitored: [RegionIdentifier.make(for: kept.id)])
        #expect(result.desired.map(\.placeID) == [kept.id, added.id])
        #expect(result.toAdd.map(\.placeID) == [added.id])
        #expect(result.toRemove.isEmpty)
    }

    @Test func 遠くなった場所と対象外になった場所と知らない識別子を外す() {
        let near = Fixtures.place(metersNorth: 100)
        let pushedOut = Fixtures.place(metersNorth: 9000)
        let visited = Fixtures.place(metersNorth: 50, status: .visited)
        let deletedID = UUID()
        let monitored: Set = [
            RegionIdentifier.make(for: near.id),
            RegionIdentifier.make(for: pushedOut.id),
            RegionIdentifier.make(for: visited.id),
            RegionIdentifier.make(for: deletedID),
            "unknown",
        ]
        let result = plan([near, pushedOut, visited], monitored: monitored, limit: 1)
        #expect(result.desired.map(\.placeID) == [near.id])
        #expect(result.toAdd.isEmpty)
        #expect(result.toRemove == [
            RegionIdentifier.make(for: pushedOut.id),
            RegionIdentifier.make(for: visited.id),
            RegionIdentifier.make(for: deletedID),
            "unknown",
        ].sorted())
    }

    @Test func 場所も監視もなければ空() {
        let result = plan([])
        #expect(result == RegionPlan(desired: [], toAdd: [], toRemove: []))
    }

    @Test func 設定から上限と半径を使う() {
        var settings = AnosaSettings.default
        settings.monitoredRegionLimit = 2
        settings.regionRadiusMeters = 150
        let places = (1...3).map { Fixtures.place(metersNorth: Double($0) * 100) }
        let result = RegionPlanner.plan(
            currentLocation: Fixtures.origin,
            places: places,
            monitoredIdentifiers: [],
            settings: settings
        )
        #expect(result.desired.map(\.placeID) == places.prefix(2).map(\.id))
        #expect(result.desired.allSatisfy { $0.radiusMeters == 150 })
    }
}

@Suite("リージョンの識別子")
struct RegionIdentifierTests {
    @Test func 往復できる() {
        let id = UUID()
        #expect(RegionIdentifier.placeID(from: RegionIdentifier.make(for: id)) == id)
    }

    @Test func 形式が違えばnil() {
        let id = UUID()
        #expect(RegionIdentifier.placeID(from: id.uuidString) == nil)
        #expect(RegionIdentifier.placeID(from: "place.") == nil)
        #expect(RegionIdentifier.placeID(from: "place.not-a-uuid") == nil)
        #expect(RegionIdentifier.placeID(from: "other.\(id.uuidString)") == nil)
    }
}

@Suite("設定: リージョン")
struct RegionSettingsTests {
    @Test func 既定値() {
        #expect(AnosaSettings.default.monitoredRegionLimit == 20)
        #expect(AnosaSettings.default.regionRadiusMeters == 500)
    }

    @Test func JSONで往復できる() throws {
        var settings = AnosaSettings.default
        settings.monitoredRegionLimit = 7
        settings.regionRadiusMeters = 250
        let decoded = try JSONDecoder().decode(AnosaSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded == settings)
    }

    @Test func 新しい項目がないJSONは既定値で読める() throws {
        let data = try JSONEncoder().encode(AnosaSettings.default)
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "monitoredRegionLimit")
        object.removeValue(forKey: "regionRadiusMeters")
        let legacy = try JSONSerialization.data(withJSONObject: object)
        #expect(try JSONDecoder().decode(AnosaSettings.self, from: legacy) == .default)
    }
}
