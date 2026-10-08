import Foundation
import Testing
@testable import AnosaKit

@Suite("Watch のコンプリケーションの内容")
struct WatchComplicationContentTests {
    static func nearby(name: String = "喫茶店", distance: Double, walkingMinutes: Int = 3) -> NearbyPlace {
        NearbyPlace(id: UUID(), name: name, coordinate: Fixtures.origin, distanceMeters: distance, walkingMinutes: walkingMinutes)
    }

    static func content(_ places: [Place], visited: [Place] = []) -> WatchComplicationContent {
        let snapshot = LocationSnapshot.make(location: Fixtures.origin, capturedAt: Fixtures.now, places: places)
        var ledger = WatchVisitedLedger()
        for place in visited {
            ledger.markVisited(place.id, at: Fixtures.now)
        }
        return WatchComplicationContent(snapshot: snapshot, ledger: ledger)
    }

    @Test func いちばん近い場所の名前と徒歩分と距離を出す() throws {
        let near = Fixtures.place(name: "喫茶店", metersNorth: 450)
        let far = Fixtures.place(name: "本屋", metersNorth: 800)

        let content = Self.content([far, near])
        let place = try #require(content.place)
        #expect(place.id == near.id)
        #expect(content.state == .nearby(place))
        #expect(content.inlineText == "喫茶店・徒歩6分")
        #expect(content.walkingText == "徒歩6分")
        #expect(content.distanceText == "450m")
        #expect(content.cornerLabel == "徒歩6分")
        #expect(content.rectangularMessage == nil)
        #expect(content.relevance >= 0.5 && content.relevance <= 1.0)
    }

    @Test func 台帳にある場所は飛ばす() {
        let near = Fixtures.place(name: "喫茶店", metersNorth: 100)
        let next = Fixtures.place(name: "本屋", metersNorth: 300)
        #expect(Self.content([near, next], visited: [near]).place?.id == next.id)
    }

    @Test func 半径ちょうどは近くにありそれより遠ければ近くにない() {
        let settings = AnosaSettings.default
        #expect(settings.notificationRadiusMeters == 500)

        let edge = WatchComplicationContent(nearest: Self.nearby(distance: 500), settings: settings)
        #expect(edge.place != nil)
        #expect(edge.relevance == 0.5)

        let beyond = WatchComplicationContent(nearest: Self.nearby(distance: 500.01), settings: settings)
        #expect(beyond.state == .noNearbyPlaces)
        #expect(beyond.place == nil)
        #expect(beyond.relevance == 0.1)
    }

    @Test func 遠い場所だけなら近くにないで名前も距離も出さない() {
        let far = Fixtures.place(name: "本屋", metersNorth: 800)
        let content = Self.content([far])
        #expect(content.state == .noNearbyPlaces)
        #expect(content.place == nil)
        #expect(content.walkingText == nil)
        #expect(content.distanceText == nil)
        #expect(content.relevance == 0.1)
        #expect(content.inlineText == "また思い出すね")
        #expect(content.rectangularMessage == "また思い出すね")
        #expect(content.cornerLabel == nil)
    }

    @Test func 全部もう行ったなら保存なしではなく近くにないで関連度0() {
        let place = Fixtures.place(metersNorth: 100)
        let content = Self.content([place], visited: [place])
        #expect(content.state == .noNearbyPlaces)
        #expect(content.place == nil)
        #expect(content.relevance == 0)
        #expect(content.cornerLabel == nil)
    }

    @Test func 行きたいが0件なら保存なし() {
        let empty = LocationSnapshot(location: Fixtures.origin, capturedAt: Fixtures.now, places: [])
        let content = WatchComplicationContent(snapshot: empty, ledger: WatchVisitedLedger())
        #expect(content.state == .noSavedPlaces)
        #expect(content.place == nil)
        #expect(content.relevance == 0)
        #expect(content.inlineText == "場所を保存してね")
        #expect(content.rectangularMessage == "場所を保存すると、ここで思い出せるよ")
        #expect(content.cornerLabel == "保存してね")
        #expect(content.walkingText == nil)
        #expect(content.distanceText == nil)
    }

    @Test func スナップショットがなければ現在地未取得() {
        let content = WatchComplicationContent(snapshot: nil, ledger: WatchVisitedLedger())
        #expect(content.state == .locationUnavailable)
        #expect(content.place == nil)
        #expect(content.relevance == 0)
        #expect(content.inlineText == "現在地を待ってるよ")
        #expect(content.rectangularMessage == "現在地がわかったら教えるね")
        #expect(content.cornerLabel == "現在地待ち")
        #expect(content.walkingText == nil)
        #expect(content.distanceText == nil)
    }

    @Test func inlineは名前が8文字までなら名前を出し9文字からは徒歩分だけ() {
        #expect(WidgetCopy.Watch.inlineNameLimit == 8)
        let eight = WatchComplicationContent(nearest: Self.nearby(name: "あいうえおかきく", distance: 100, walkingMinutes: 2))
        #expect(eight.inlineText == "あいうえおかきく・徒歩2分")

        let nine = WatchComplicationContent(nearest: Self.nearby(name: "あいうえおかきくけ", distance: 100, walkingMinutes: 2))
        #expect(nine.inlineText == "行きたい場所まで徒歩2分")
        #expect(nine.place?.name == "あいうえおかきくけ")

        // 絵文字・結合文字も 1 文字として数える。
        #expect(WidgetCopy.Watch.inline(placeName: "🇯🇵喫茶ぽっぽ店", walkingMinutes: 1) == "🇯🇵喫茶ぽっぽ店・徒歩1分")
    }

    @Test func Watchの文言はどれも空でなく互いに違う() {
        let copies = [
            WidgetCopy.Watch.nearbyCaption,
            WidgetCopy.Watch.noNearbyPlaces,
            WidgetCopy.Watch.noSavedPlaces, WidgetCopy.Watch.noSavedPlacesShort, WidgetCopy.Watch.noSavedPlacesCorner,
            WidgetCopy.Watch.locationUnavailable, WidgetCopy.Watch.locationUnavailableShort, WidgetCopy.Watch.locationUnavailableCorner,
            WatchComplicationContent.emptyMessage,
        ]
        #expect(copies.allSatisfy { !$0.isEmpty })
        #expect(Set(copies).count == copies.count)
        #expect(WidgetCopy.Watch.nearbyCaption == "近くにあるよ")
    }

    @Test func 状態ごとのinlineとrectangularとcornerはそれぞれ違う() {
        let states: [WatchComplicationContent] = [
            WatchComplicationContent(nearest: Self.nearby(distance: 100)),
            WatchComplicationContent(state: .noNearbyPlaces, relevance: 0),
            WatchComplicationContent(state: .noSavedPlaces, relevance: 0),
            WatchComplicationContent(state: .locationUnavailable, relevance: 0),
        ]
        #expect(Set(states.map(\.inlineText)).count == 4)
        #expect(Set(states.map(\.rectangularMessage)).count == 4)
        #expect(Set(states.map(\.cornerLabel)).count == 4)
    }

    @Test func 関連度は半径以内で0_5から1_0遠ければ0_1() {
        let settings = AnosaSettings.default
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
        let content = WatchComplicationContent(nearest: Self.nearby(distance: 500), settings: settings)
        #expect(content.place != nil)
        #expect(content.relevance == 0.75)

        settings.notificationRadiusMeters = 0
        #expect(WatchComplicationContent(nearest: Self.nearby(distance: 0), settings: settings).place != nil)
        #expect(WatchComplicationContent(nearest: Self.nearby(distance: 1), settings: settings).state == .noNearbyPlaces)
        #expect(WatchComplicationContent.relevance(for: Self.nearby(distance: 0), settings: settings) == 1.0)
        #expect(WatchComplicationContent.relevance(for: Self.nearby(distance: 1), settings: settings) == 0.1)
    }

    @Test func 距離はiOSウィジェットと同じ書式で出す() {
        for meters in [0, 123.4, 250] {
            let content = WatchComplicationContent(nearest: Self.nearby(distance: meters))
            #expect(content.distanceText == DistanceText.format(meters: meters))
        }
        #expect(WatchComplicationContent(nearest: Self.nearby(distance: 123.4)).distanceText == "120m")
        var wide = AnosaSettings.default
        wide.notificationRadiusMeters = 2000
        #expect(WatchComplicationContent(nearest: Self.nearby(distance: 996), settings: wide).distanceText == "1.0km")
    }
}
