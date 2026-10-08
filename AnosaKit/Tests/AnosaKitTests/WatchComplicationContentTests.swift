import Foundation
import Testing
@testable import AnosaKit

@Suite("Watch のコンプリケーションの内容")
struct WatchComplicationContentTests {
    static func nearby(name: String = "喫茶店", distance: Double, walkingMinutes: Int = 3) -> NearbyPlace {
        NearbyPlace(id: UUID(), name: name, coordinate: Fixtures.origin, distanceMeters: distance, walkingMinutes: walkingMinutes)
    }

    @Test func いちばん近い場所の名前と徒歩分と距離を出す() throws {
        let near = Fixtures.place(name: "喫茶店", metersNorth: 450)
        let far = Fixtures.place(name: "本屋", metersNorth: 800)
        let snapshot = LocationSnapshot.make(location: Fixtures.origin, capturedAt: Fixtures.now, places: [far, near])

        let content = WatchComplicationContent(snapshot: snapshot, ledger: WatchVisitedLedger())
        let place = try #require(content.place)
        #expect(place.id == near.id)
        #expect(content.inlineText == "喫茶店・徒歩6分")
        #expect(content.walkingText == "徒歩6分")
        #expect(content.distanceText == "450m")
    }

    @Test func 台帳にある場所は飛ばす() {
        let near = Fixtures.place(name: "喫茶店", metersNorth: 100)
        let next = Fixtures.place(name: "本屋", metersNorth: 300)
        let snapshot = LocationSnapshot.make(location: Fixtures.origin, capturedAt: Fixtures.now, places: [near, next])
        var ledger = WatchVisitedLedger()
        ledger.markVisited(near.id, at: Fixtures.now)
        #expect(WatchComplicationContent(snapshot: snapshot, ledger: ledger).place?.id == next.id)
    }

    @Test func 場所がなければ語りかけの文言で関連度0() {
        let empty = LocationSnapshot(location: Fixtures.origin, capturedAt: Fixtures.now, places: [])
        for content in [
            WatchComplicationContent(snapshot: nil, ledger: WatchVisitedLedger()),
            WatchComplicationContent(snapshot: empty, ledger: WatchVisitedLedger()),
        ] {
            #expect(content.place == nil)
            #expect(content.inlineText == "近くにはまだないよ")
            #expect(content.walkingText == nil)
            #expect(content.distanceText == nil)
            #expect(content.relevance == 0)
        }
        #expect(WatchComplicationContent.emptyMessage == "近くの行きたい場所はまだないよ")
    }

    @Test func 全部もう行ったなら場所なし() {
        let place = Fixtures.place(metersNorth: 100)
        let snapshot = LocationSnapshot.make(location: Fixtures.origin, capturedAt: Fixtures.now, places: [place])
        var ledger = WatchVisitedLedger()
        ledger.markVisited(place.id, at: Fixtures.now)
        let content = WatchComplicationContent(snapshot: snapshot, ledger: ledger)
        #expect(content.place == nil)
        #expect(content.relevance == 0)
    }

    @Test func 関連度は半径以内で0_5から1_0遠ければ0_1() {
        let settings = AnosaSettings.default
        #expect(settings.notificationRadiusMeters == 500)
        func relevance(_ distance: Double) -> Double {
            WatchComplicationContent.relevance(for: Self.nearby(distance: distance), settings: settings)
        }
        #expect(relevance(0) == 1.0)
        #expect(relevance(250) == 0.75)
        #expect(relevance(500) == 0.5)
        #expect(relevance(500.01) == 0.1)
        #expect(relevance(3000) == 0.1)
        #expect(WatchComplicationContent.relevance(for: nil, settings: settings) == 0)
    }

    @Test func 関連度は設定の半径に従う() {
        var settings = AnosaSettings.default
        settings.notificationRadiusMeters = 1000
        let content = WatchComplicationContent(place: Self.nearby(distance: 500), settings: settings)
        #expect(content.relevance == 0.75)

        settings.notificationRadiusMeters = 0
        #expect(WatchComplicationContent.relevance(for: Self.nearby(distance: 0), settings: settings) == 1.0)
        #expect(WatchComplicationContent.relevance(for: Self.nearby(distance: 1), settings: settings) == 0.1)
    }

    @Test func 距離はiOSウィジェットと同じ書式で出す() {
        for meters in [0, 123.4, 996, 1250, 12_340] {
            let content = WatchComplicationContent(place: Self.nearby(distance: meters))
            #expect(content.distanceText == DistanceText.format(meters: meters))
        }
        #expect(WatchComplicationContent(place: Self.nearby(distance: 123.4)).distanceText == "120m")
        #expect(WatchComplicationContent(place: Self.nearby(distance: 996)).distanceText == "1.0km")
    }
}
