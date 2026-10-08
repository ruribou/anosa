import Foundation
import Testing
@testable import AnosaKit

@Suite("ウィジェットの表示")
struct NearestPlaceDisplayTests {
    @Test func スナップショットがなければ位置未取得の案内() {
        let display = NearestPlaceDisplay(snapshot: nil)
        #expect(display == .locationUnavailable)
        #expect(display.message == WidgetCopy.locationUnavailable)
        #expect(display.inlineText == WidgetCopy.locationUnavailableShort)
    }

    @Test func 近くに行きたい場所がなければ空の案内() {
        let snapshot = LocationSnapshot.make(
            location: Fixtures.origin,
            capturedAt: Fixtures.now,
            places: [Fixtures.place(metersNorth: 100, status: .visited), Fixtures.place(metersNorth: 200, status: .archived)]
        )
        let display = NearestPlaceDisplay(snapshot: snapshot)
        #expect(display == .noNearbyPlaces)
        #expect(display.message == WidgetCopy.noNearbyPlaces)
        #expect(display.inlineText == WidgetCopy.noNearbyPlacesShort)
    }

    @Test func 空の状態の案内はそれぞれ違い空でない() {
        let messages = [
            WidgetCopy.locationUnavailable, WidgetCopy.locationUnavailableShort,
            WidgetCopy.noNearbyPlaces, WidgetCopy.noNearbyPlacesShort,
        ]
        #expect(Set(messages).count == messages.count)
        #expect(messages.allSatisfy { !$0.isEmpty && !$0.localizedCaseInsensitiveContains("Anosa") })
    }

    @Test func いちばん近い行きたい場所の名前と距離と徒歩分() throws {
        let near = Fixtures.place(name: "テスト喫茶", metersNorth: 450)
        let far = Fixtures.place(name: "遠い店", metersNorth: 1200)
        let visited = Fixtures.place(name: "行った店", metersNorth: 50, status: .visited)
        let snapshot = LocationSnapshot.make(location: Fixtures.origin, capturedAt: Fixtures.now, places: [far, visited, near])

        let display = NearestPlaceDisplay(snapshot: snapshot)
        guard case .nearest(let summary) = display else {
            Issue.record("場所ありの表示にならない: \(display)")
            return
        }
        #expect(summary.id == near.id)
        #expect(summary.name == "テスト喫茶")
        #expect(abs(summary.distanceMeters - 450) < 0.01)
        #expect(summary.distanceText == "450m")
        #expect(summary.walkingText == "徒歩6分")
        #expect(display.message == nil)
        #expect(display.inlineText == "テスト喫茶・450m")
    }

    @Test func 古いスナップショットでも表示は変わらない() {
        let place = Fixtures.place(name: "テスト喫茶", metersNorth: 300)
        let fresh = LocationSnapshot.make(location: Fixtures.origin, capturedAt: Fixtures.now, places: [place])
        let old = LocationSnapshot.make(location: Fixtures.origin, capturedAt: Fixtures.now.addingTimeInterval(-30 * Fixtures.day), places: [place])
        #expect(NearestPlaceDisplay(snapshot: old) == NearestPlaceDisplay(snapshot: fresh))
    }

    @Test func 徒歩分は通知のbodyと同じ書き方() throws {
        let place = Fixtures.place(name: "テスト喫茶", metersNorth: 250)
        let candidate = try #require(Fixtures.decide(places: [place]))
        let snapshot = LocationSnapshot.make(location: Fixtures.origin, capturedAt: Fixtures.now, places: [place])
        guard case .nearest(let summary) = NearestPlaceDisplay(snapshot: snapshot) else {
            Issue.record("場所ありの表示にならない")
            return
        }
        #expect(NotificationCopy.body(for: candidate) == "テスト喫茶・\(summary.walkingText)")
    }

    @Test(arguments: [
        (0.0, "0m"),
        (4.9, "0m"),
        (5.0, "10m"),
        (350.0, "350m"),
        (354.9, "350m"),
        (355.0, "360m"),
        (994.0, "990m"),
        (994.9, "990m"),
        (995.0, "1.0km"),
        (999.9, "1.0km"),
        (1000.0, "1.0km"),
        (1049.0, "1.0km"),
        (1049.9, "1.0km"),
        (1050.0, "1.1km"),
        (1234.0, "1.2km"),
        (9949.0, "9.9km"),
        (9950.0, "10.0km"),
        (12_345.0, "12.3km"),
        (123_456.0, "123.5km"),
        (20_037_508.0, "20037.5km"),
    ])
    func 距離の書式(meters: Double, expected: String) {
        #expect(DistanceText.format(meters: meters) == expected)
    }

    @Test func 範囲外の距離でも落ちない() {
        #expect(DistanceText.format(meters: -10) == "0m")
        #expect(DistanceText.format(meters: .nan) == "0m")
        #expect(DistanceText.format(meters: .infinity) == "100000.0km")
        #expect(DistanceText.format(meters: 1e300) == "100000.0km")
    }
}
