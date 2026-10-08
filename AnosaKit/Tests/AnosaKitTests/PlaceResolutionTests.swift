import Foundation
import Testing
@testable import AnosaKit

@Suite("検索候補から保存先を決める")
struct PlaceResolutionTests {
    private static let tokyoTower = Coordinate(latitude: 35.658581, longitude: 139.745433)
    /// 東京タワーから北へ約 111m。
    private static let near111m = Coordinate(latitude: 35.659581, longitude: 139.745433)
    /// 東京タワーから北へ約 222m。
    private static let far222m = Coordinate(latitude: 35.660581, longitude: 139.745433)
    /// 東京タワーから北へ約 1.1km。
    private static let far1km = Coordinate(latitude: 35.668581, longitude: 139.745433)

    private func candidate(_ name: String, _ coordinate: Coordinate = tokyoTower) -> PlaceCandidate {
        PlaceCandidate(name: name, coordinate: coordinate)
    }

    // MARK: 件数

    @Test func 候補なしはnone() {
        #expect(PlaceResolution.decide(candidates: [], query: PlaceQuery(text: "東京タワー")) == .none)
    }

    @Test func 候補1件は名前が違ってもsingle() {
        let only = candidate("Tokyo Tower")
        #expect(PlaceResolution.decide(candidates: [only], query: PlaceQuery(text: "東京タワー")) == .single(only))
    }

    @Test func 座標だけのクエリで候補1件はsingle() {
        let only = candidate("芝公園4丁目")
        #expect(PlaceResolution.decide(candidates: [only], query: PlaceQuery(coordinate: Self.tokyoTower)) == .single(only))
    }

    @Test func 座標だけのクエリで候補複数はchoose() {
        let candidates = [candidate("芝公園4丁目"), candidate("芝公園")]
        #expect(PlaceResolution.decide(candidates: candidates, query: PlaceQuery(coordinate: Self.tokyoTower)) == .choose(candidates))
    }

    // MARK: 座標なし（先頭の名前で判定）

    @Test func 先頭の名前が一致すればsingle() {
        let candidates = [candidate("東京タワー"), candidate("東京タワー 駐車場")]
        #expect(PlaceResolution.decide(candidates: candidates, query: PlaceQuery(text: "東京タワー")) == .single(candidates[0]))
    }

    @Test func 一致するのが先頭以外ならchoose() {
        let candidates = [candidate("東京タワー 駐車場"), candidate("東京タワー")]
        #expect(PlaceResolution.decide(candidates: candidates, query: PlaceQuery(text: "東京タワー")) == .choose(candidates))
    }

    @Test func どれも一致しなければchoose() {
        let candidates = [candidate("スターバックス 渋谷店"), candidate("スターバックス 新宿店")]
        #expect(PlaceResolution.decide(candidates: candidates, query: PlaceQuery(text: "スターバックス")) == .choose(candidates))
    }

    @Test func 空白だけの検索語は検索語なしとしてchoose() {
        let candidates = [candidate("東京タワー"), candidate("東京タワー 駐車場")]
        #expect(PlaceResolution.decide(candidates: candidates, query: PlaceQuery(text: "  ")) == .choose(candidates))
    }

    // MARK: 座標あり（近くの同名を選ぶ）

    @Test func 座標から200m以内の同名で最も近いものをsingle() {
        let candidates = [
            candidate("東京タワー", Self.far222m),
            candidate("東京タワー", Self.near111m),
            candidate("東京タワー 駐車場", Self.tokyoTower),
        ]
        let query = PlaceQuery(text: "東京タワー", coordinate: Self.tokyoTower)
        #expect(PlaceResolution.decide(candidates: candidates, query: query) == .single(candidates[1]))
    }

    @Test func 同名でも200mより遠ければchoose() {
        let candidates = [candidate("東京タワー", Self.far222m), candidate("東京タワー", Self.far1km)]
        let query = PlaceQuery(text: "東京タワー", coordinate: Self.tokyoTower)
        #expect(PlaceResolution.decide(candidates: candidates, query: query) == .choose(candidates))
    }

    @Test func 座標があるときは先頭が同名でも遠ければchoose() {
        let candidates = [candidate("東京タワー", Self.far1km), candidate("東京タワー 駐車場", Self.tokyoTower)]
        let query = PlaceQuery(text: "東京タワー", coordinate: Self.tokyoTower)
        #expect(PlaceResolution.decide(candidates: candidates, query: query) == .choose(candidates))
    }

    @Test func 近くても名前が違えばchoose() {
        let candidates = [candidate("東京タワー 駐車場", Self.tokyoTower), candidate("芝公園", Self.near111m)]
        let query = PlaceQuery(text: "東京タワー", coordinate: Self.tokyoTower)
        #expect(PlaceResolution.decide(candidates: candidates, query: query) == .choose(candidates))
    }

    // MARK: 名前の正規化

    @Test func 全角半角と大文字小文字と空白記号を無視して一致() {
        #expect(PlaceResolution.normalizedName("ＴＯＫＹＯ　Tower!") == PlaceResolution.normalizedName("tokyo tower"))
        #expect(PlaceResolution.normalizedName("ﾄｳｷｮｳ・ﾀﾜｰ") == PlaceResolution.normalizedName("トウキョウタワー"))
    }

    @Test func 文字が違えば一致しない() {
        #expect(PlaceResolution.normalizedName("東京タワー") != PlaceResolution.normalizedName("東京タワー駐車場"))
    }
}

@Suite("検索候補から Place を作る")
struct PlaceCandidateTests {
    @Test func makePlaceは行きたいで座標と住所と出典を引き継ぐ() {
        let savedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let url = URL(string: "https://maps.apple.com/?q=Tokyo+Tower")
        let candidate = PlaceCandidate(
            name: "東京タワー",
            coordinate: Coordinate(latitude: 35.658581, longitude: 139.745433),
            address: "東京都港区芝公園4丁目2-8"
        )
        let place = candidate.makePlace(sourceURL: url, savedAt: savedAt)
        #expect(place.name == "東京タワー")
        #expect(place.coordinate == candidate.coordinate)
        #expect(place.address == "東京都港区芝公園4丁目2-8")
        #expect(place.sourceURL == url)
        #expect(place.savedAt == savedAt)
        #expect(place.status == .wantToGo)
        #expect(place.notifiedCount == 0)
    }
}
