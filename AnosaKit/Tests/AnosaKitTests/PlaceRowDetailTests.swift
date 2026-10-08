import Foundation
import Testing
@testable import AnosaKit

@Suite("一覧の行の文言")
struct PlaceRowDetailTests {
    private let id = UUID()

    private func place(status: PlaceStatus = .wantToGo, address: String? = "架空県架空市 1-2-3") -> Place {
        var place = Fixtures.place(id: id, name: "架空の喫茶店", savedAt: Fixtures.date(2026, 9, 17, 12, 0), status: status)
        place.address = address
        return place
    }

    private func snapshot(distance: Double = 650, walking: Int = 8, id: UUID? = nil) -> LocationSnapshot {
        LocationSnapshot(
            location: Fixtures.origin,
            capturedAt: Fixtures.now,
            places: [
                NearbyPlace(id: UUID(), name: "別の場所", coordinate: Fixtures.origin, distanceMeters: 100, walkingMinutes: 2),
                NearbyPlace(id: id ?? self.id, name: "架空の喫茶店", coordinate: Fixtures.origin, distanceMeters: distance, walkingMinutes: walking),
            ]
        )
    }

    private func detail(_ place: Place, _ snapshot: LocationSnapshot?) -> PlaceRowDetail {
        PlaceRowDetail(place: place, snapshot: snapshot, now: Fixtures.now, calendar: Fixtures.tokyo)
    }

    @Test func 行きたいでスナップショットにあれば距離と徒歩分() {
        let detail = detail(place(), snapshot())
        #expect(detail.savedAgoText == "3週間前に保存")
        #expect(detail.distanceText == "650m・徒歩8分")
        #expect(detail.spokenDistanceText == "650メートル、徒歩8分")
    }

    @Test func 距離はウィジェットと同じ書式() {
        let detail = detail(place(), snapshot(distance: 1234, walking: 16))
        #expect(detail.distanceText == "1.2km・徒歩16分")
        #expect(detail.spokenDistanceText == "1.2キロメートル、徒歩16分")
    }

    @Test func スナップショットにない場所は距離を出さない() {
        #expect(detail(place(), snapshot(id: UUID())).distanceText == nil)
        #expect(detail(place(), nil).distanceText == nil)
        #expect(detail(place(), nil).spokenDistanceText == nil)
    }

    @Test(arguments: [PlaceStatus.visited, .archived])
    func 行きたい以外は距離を出さない(status: PlaceStatus) {
        let detail = detail(place(status: status), snapshot())
        #expect(detail.distanceText == nil)
        #expect(detail.spokenDistanceText == nil)
        #expect(detail.savedAgoText == "3週間前に保存")
    }

    @Test func 読み上げは名前_住所_期間_距離の順() {
        #expect(detail(place(), snapshot()).accessibilityLabel == "架空の喫茶店、架空県架空市 1-2-3、3週間前に保存、650メートル、徒歩8分")
    }

    @Test func 住所や距離がなければ読み上げに空の区切りを入れない() {
        #expect(detail(place(address: nil), nil).accessibilityLabel == "架空の喫茶店、3週間前に保存")
        #expect(detail(place(address: ""), nil).accessibilityLabel == "架空の喫茶店、3週間前に保存")
    }

    @Test(arguments: [
        (0.0, "0メートル"), (650.0, "650メートル"), (994.0, "990メートル"), (995.0, "1.0キロメートル"), (1234.0, "1.2キロメートル"),
    ])
    func 読み上げ用の距離はformatと同じ丸め(meters: Double, expected: String) {
        #expect(DistanceText.spoken(meters: meters) == expected)
    }
}
