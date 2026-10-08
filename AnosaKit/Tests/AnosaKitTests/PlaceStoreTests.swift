import Foundation
import SwiftData
import Testing
@testable import AnosaKit

@MainActor
@Suite("PlaceStore（SwiftData）")
struct PlaceStoreTests {
    let store: PlaceStore

    init() throws {
        store = PlaceStore(container: try AnosaStore.makeContainer(inMemory: true))
    }

    @Test func 保存した場所を全項目そのまま取得できる() throws {
        let place = Place(
            name: "東京タワー",
            latitude: 35.658581,
            longitude: 139.745433,
            address: "東京都港区芝公園",
            sourceURL: URL(string: "https://maps.apple.com/?q=Tokyo+Tower"),
            note: "展望台",
            savedAt: Fixtures.now,
            status: .visited,
            lastNotifiedAt: Fixtures.now.addingTimeInterval(-Fixtures.day),
            snoozedUntil: Fixtures.now.addingTimeInterval(3600),
            notifiedCount: 3,
            openingHours: OpeningHours(periods: [
                OpeningPeriod(weekday: 2, open: TimeOfDay(hour: 9, minute: 0), close: TimeOfDay(hour: 22, minute: 30)),
            ])
        )
        try store.save(place)

        #expect(try store.place(id: place.id) == place)
        #expect(try store.places() == [place])
    }

    @Test func 営業時間なしの場所はnilのまま戻る() throws {
        let place = Fixtures.place(openingHours: nil)
        try store.save(place)
        #expect(try store.place(id: place.id)?.openingHours == nil)
    }

    @Test func 存在しないidはnil() throws {
        try store.save(Fixtures.place())
        #expect(try store.place(id: UUID()) == nil)
    }

    @Test func 同じidで再保存すると更新され重複しない() throws {
        var place = Fixtures.place(name: "最初の名前")
        try store.save(place)
        place.name = "変更後の名前"
        place.notifiedCount = 2
        try store.save(place)

        let all = try store.places()
        #expect(all.count == 1)
        #expect(all.first == place)
    }

    @Test func 保存日時の新しい順に並ぶ() throws {
        let old = Fixtures.place(name: "古い", savedAt: Fixtures.now.addingTimeInterval(-3 * Fixtures.day))
        let new = Fixtures.place(name: "新しい", savedAt: Fixtures.now)
        let middle = Fixtures.place(name: "中間", savedAt: Fixtures.now.addingTimeInterval(-Fixtures.day))
        try store.save(old)
        try store.save(new)
        try store.save(middle)

        #expect(try store.places().map(\.name) == ["新しい", "中間", "古い"])
    }

    @Test func ステータスで絞り込める() throws {
        let want = Fixtures.place(name: "行きたい", status: .wantToGo)
        let visited = Fixtures.place(name: "行った", status: .visited)
        let archived = Fixtures.place(name: "アーカイブ", status: .archived)
        for place in [want, visited, archived] { try store.save(place) }

        #expect(try store.places(status: .wantToGo).map(\.id) == [want.id])
        #expect(try store.places(status: .visited).map(\.id) == [visited.id])
        #expect(try store.places(status: .archived).map(\.id) == [archived.id])
        #expect(try store.places().count == 3)
    }

    @Test func setStatusでステータスが変わり絞り込み結果が移る() throws {
        let place = Fixtures.place(status: .wantToGo)
        let other = Fixtures.place(name: "別の場所", status: .wantToGo)
        try store.save(place)
        try store.save(other)

        try store.setStatus(.visited, for: place.id)

        #expect(try store.place(id: place.id)?.status == .visited)
        #expect(try store.places(status: .wantToGo).map(\.id) == [other.id])
        #expect(try store.places(status: .visited).map(\.id) == [place.id])
    }

    @Test func setStatusはステータス以外の項目を変えない() throws {
        let place = Fixtures.place(lastNotifiedAt: Fixtures.now)
        try store.save(place)
        try store.setStatus(.archived, for: place.id)

        var expected = place
        expected.status = .archived
        #expect(try store.place(id: place.id) == expected)
    }

    @Test func 存在しないidのsetStatusは何もしない() throws {
        let place = Fixtures.place()
        try store.save(place)
        try store.setStatus(.visited, for: UUID())
        #expect(try store.places() == [place])
    }

    @Test func deleteで削除され他は残る() throws {
        let place = Fixtures.place()
        let other = Fixtures.place(name: "残る場所")
        try store.save(place)
        try store.save(other)

        try store.delete(id: place.id)

        #expect(try store.place(id: place.id) == nil)
        #expect(try store.places().map(\.id) == [other.id])
        try store.delete(id: UUID())
        #expect(try store.places().count == 1)
    }

    @Test func 別のコンテキストからも保存内容が見える() throws {
        let container = try AnosaStore.makeContainer(inMemory: true)
        let writer = PlaceStore(context: ModelContext(container))
        let place = Fixtures.place()
        try writer.save(place)

        let reader = PlaceStore(context: ModelContext(container))
        #expect(try reader.place(id: place.id) == place)
    }
}
