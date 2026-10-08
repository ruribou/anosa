import Foundation
import Testing
@testable import AnosaKit

@Suite("共有入力のパース")
struct SharedInputParserTests {
    private func query(url: String? = nil, text: String? = nil) -> PlaceQuery? {
        SharedInputParser.query(from: SharedInput(url: url.flatMap(URL.init(string:)), text: text))
    }

    private static let tokyoTower = Coordinate(latitude: 35.658581, longitude: 139.745433)

    // MARK: Apple マップ

    @Test func AppleマップのqとllからPlaceQueryを作る() {
        let result = query(url: "https://maps.apple.com/?q=%E6%9D%B1%E4%BA%AC%E3%82%BF%E3%83%AF%E3%83%BC&ll=35.658581,139.745433")
        #expect(result?.text == "東京タワー")
        #expect(result?.coordinate == Self.tokyoTower)
        #expect(result?.sourceURL?.host == "maps.apple.com")
    }

    @Test func Appleマップのqのプラスは空白() {
        #expect(query(url: "https://maps.apple.com/?q=Tokyo+Tower")?.text == "Tokyo Tower")
    }

    @Test func Appleマップの新形式nameとcoordinate() {
        let result = query(url: "https://maps.apple.com/place?name=Tokyo%20Tower&coordinate=35.658581,139.745433")
        #expect(result == PlaceQuery(text: "Tokyo Tower", coordinate: Self.tokyoTower, sourceURL: URL(string: "https://maps.apple.com/place?name=Tokyo%20Tower&coordinate=35.658581,139.745433")))
    }

    @Test func Appleマップはnameをqより優先する() {
        #expect(query(url: "https://maps.apple.com/?q=Tower&name=Tokyo+Tower")?.text == "Tokyo Tower")
    }

    @Test func Appleマップのaddressだけでも名前になる() {
        let result = query(url: "https://maps.apple.com/?address=4-2-8+Shibakoen,+Minato,+Tokyo")
        #expect(result?.text == "4-2-8 Shibakoen, Minato, Tokyo")
        #expect(result?.coordinate == nil)
    }

    @Test func Appleマップのllだけならテキストを名前にする() {
        let result = query(url: "https://maps.apple.com/?ll=35.658581,139.745433", text: " 東京タワー\n")
        #expect(result?.text == "東京タワー")
        #expect(result?.coordinate == Self.tokyoTower)
    }

    @Test func Appleマップのqが座標なら座標として扱う() {
        let result = query(url: "https://maps.apple.com/?q=35.658581,139.745433")
        #expect(result?.text == nil)
        #expect(result?.coordinate == Self.tokyoTower)
    }

    @Test func Appleマップの名前も座標もないURLは地図以外と同じ扱い() {
        #expect(query(url: "https://maps.apple.com/?t=m") == nil)
        #expect(query(url: "https://maps.apple.com/?t=m", text: "東京タワー")?.text == "東京タワー")
    }

    // MARK: Google マップ

    @Test func Googleマップのplaceパスと座標() {
        let result = query(url: "https://www.google.com/maps/place/%E6%9D%B1%E4%BA%AC%E3%82%BF%E3%83%AF%E3%83%BC/@35.658581,139.745433,17z/data=!3m1")
        #expect(result?.text == "東京タワー")
        #expect(result?.coordinate == Self.tokyoTower)
    }

    @Test func Googleマップのplaceパスのプラスは空白() {
        let result = query(url: "https://www.google.co.jp/maps/place/Tokyo+Tower/")
        #expect(result?.text == "Tokyo Tower")
        #expect(result?.coordinate == nil)
    }

    @Test func Googleマップのapi形式query() {
        let result = query(url: "https://www.google.com/maps/search/?api=1&query=Tokyo%20Tower")
        #expect(result?.text == "Tokyo Tower")
    }

    @Test func Googleマップのqが座標() {
        let result = query(url: "https://maps.google.com/?q=35.658581,139.745433")
        #expect(result?.text == nil)
        #expect(result?.coordinate == Self.tokyoTower)
    }

    @Test func Googleマップのsearchパス() {
        #expect(query(url: "https://www.google.com/maps/search/Tokyo+Tower/@35.658581,139.745433,15z")
            == PlaceQuery(text: "Tokyo Tower", coordinate: Self.tokyoTower, sourceURL: URL(string: "https://www.google.com/maps/search/Tokyo+Tower/@35.658581,139.745433,15z")))
    }

    @Test func Googleのmaps以外のパスは地図URLとみなさない() {
        #expect(query(url: "https://www.google.com/search?q=Tokyo+Tower") == nil)
    }

    // MARK: テキスト

    @Test func テキストの前後空白と改行を整理する() {
        let result = query(text: "\n  東京タワー\n\n東京都港区　芝公園  \n")
        #expect(result == PlaceQuery(text: "東京タワー 東京都港区 芝公園"))
    }

    @Test func テキスト中の地図URLを解釈しURL部分は名前から除く() {
        let result = query(text: "東京タワー https://maps.apple.com/?ll=35.658581,139.745433")
        #expect(result?.text == "東京タワー")
        #expect(result?.coordinate == Self.tokyoTower)
        #expect(result?.sourceURL?.host == "maps.apple.com")
    }

    @Test func テキスト中の地図URLに名前があればURLの名前を優先する() {
        let result = query(text: "ここ行きたい\nhttps://www.google.com/maps/place/Tokyo+Tower/@35.658581,139.745433,17z")
        #expect(result?.text == "Tokyo Tower")
        #expect(result?.coordinate == Self.tokyoTower)
    }

    @Test func 空白だけのテキストはnil() {
        #expect(query(text: " \n\t ") == nil)
        #expect(query() == nil)
    }

    // MARK: 地図以外の URL

    @Test func 地図以外のURLだけならnil() {
        #expect(query(url: "https://example.com/shops/tokyo-tower") == nil)
    }

    @Test func 地図以外のURLとテキストならテキストを使いURLを残す() {
        let result = query(url: "https://example.com/article/1", text: "東京タワーの記事")
        #expect(result == PlaceQuery(text: "東京タワーの記事", sourceURL: URL(string: "https://example.com/article/1")))
    }

    @Test func テキストがURLだけならnil() {
        #expect(query(text: "https://example.com/article/1") == nil)
    }

    @Test func httpでないURLは無視する() {
        #expect(query(url: "file:///tmp/maps.apple.com", text: "東京タワー") == PlaceQuery(text: "東京タワー"))
    }

    // MARK: 座標

    @Test(arguments: ["91,0", "0,181", "abc,1", "35.6", ""])
    func 不正な座標はnil(value: String) {
        #expect(SharedInputParser.parseCoordinate(value) == nil)
    }

    @Test func 座標は空白と3つ目以降の要素を許す() {
        #expect(SharedInputParser.parseCoordinate(" 35.658581 , 139.745433 ,17z") == Self.tokyoTower)
        #expect(SharedInputParser.parseCoordinate("-33.8568,151.2153") == Coordinate(latitude: -33.8568, longitude: 151.2153))
    }
}
