import Foundation
import Testing
@testable import AnosaKit

@Suite("Share Extension の画面遷移と入力の扱い")
struct ShareFlowTests {
    private static let tokyoTower = Coordinate(latitude: 35.658581, longitude: 139.745433)
    /// 東京タワーから北へ約 1.1km。
    private static let far1km = Coordinate(latitude: 35.668581, longitude: 139.745433)

    private static let mapURL = URL(string: "https://maps.apple.com/?q=%E6%9D%B1%E4%BA%AC%E3%82%BF%E3%83%AF%E3%83%BC")!
    private static let pageURL = URL(string: "https://example.com/article")!

    private func candidate(_ name: String, _ coordinate: Coordinate = tokyoTower) -> PlaceCandidate {
        PlaceCandidate(name: name, coordinate: coordinate)
    }

    // MARK: firstStep

    @Test func 入力から何も取れなければ空の検索欄で候補選択() {
        #expect(ShareFlow.firstStep(query: nil, candidates: []) == .choose(searchText: "", candidates: []))
    }

    @Test func 入力から何も取れなければ候補があっても保存しない() {
        let only = candidate("東京タワー")
        #expect(ShareFlow.firstStep(query: nil, candidates: [only]) == .choose(searchText: "", candidates: []))
    }

    @Test func 候補1件なら確認なしで保存() {
        let only = candidate("東京タワー")
        #expect(ShareFlow.firstStep(query: PlaceQuery(text: "東京タワー"), candidates: [only]) == .save(only))
    }

    @Test func 複数候補で名前と座標が一致すれば確認なしで保存() {
        let match = candidate("東京タワー")
        let candidates = [candidate("東京タワー", Self.far1km), match]
        let query = PlaceQuery(text: "東京タワー", coordinate: Self.tokyoTower)
        #expect(ShareFlow.firstStep(query: query, candidates: candidates) == .save(match))
    }

    @Test func 複数候補で名前が一致しなければクエリのテキストで候補選択() {
        let candidates = [candidate("東京タワー 駐車場"), candidate("東京タワー前")]
        let query = PlaceQuery(text: "東京タワー")
        #expect(ShareFlow.firstStep(query: query, candidates: candidates) == .choose(searchText: "東京タワー", candidates: candidates))
    }

    @Test func 座標だけのクエリで複数候補なら空の検索欄で候補選択() {
        let candidates = [candidate("芝公園4丁目"), candidate("芝公園")]
        let query = PlaceQuery(coordinate: Self.tokyoTower)
        #expect(ShareFlow.firstStep(query: query, candidates: candidates) == .choose(searchText: "", candidates: candidates))
    }

    @Test func 候補なしならクエリのテキストで空の候補選択() {
        #expect(ShareFlow.firstStep(query: PlaceQuery(text: "東京タワー"), candidates: []) == .choose(searchText: "東京タワー", candidates: []))
    }

    // MARK: sourceURL

    @Test func クエリのURLを共有URLより優先する() {
        let query = PlaceQuery(text: "東京タワー", sourceURL: Self.mapURL)
        #expect(ShareFlow.sourceURL(query: query, sharedURL: Self.pageURL) == Self.mapURL)
    }

    @Test func クエリにURLがなければ共有されたWebURL() {
        #expect(ShareFlow.sourceURL(query: PlaceQuery(text: "東京タワー"), sharedURL: Self.pageURL) == Self.pageURL)
    }

    @Test func クエリがなくても共有されたWebURLを使う() {
        #expect(ShareFlow.sourceURL(query: nil, sharedURL: Self.pageURL) == Self.pageURL)
    }

    @Test(arguments: ["file:///tmp/a.txt", "mailto:someone@example.com", "maps://?q=a"])
    func 共有URLがWebURLでなければnil(_ string: String) {
        #expect(ShareFlow.sourceURL(query: PlaceQuery(text: "東京タワー"), sharedURL: URL(string: string)!) == nil)
    }

    @Test func どちらもなければnil() {
        #expect(ShareFlow.sourceURL(query: nil, sharedURL: nil) == nil)
    }

    @Test(arguments: ["http://example.com", "https://example.com", "HTTPS://example.com"])
    func httpとhttpsはWebURL(_ string: String) {
        #expect(ShareFlow.isWebURL(URL(string: string)!))
    }

    // MARK: sharedText

    @Test func 添付のテキストを最優先する() {
        #expect(ShareFlow.sharedText(attachmentText: "添付", contentText: "本文", title: "タイトル") == "添付")
    }

    @Test func 添付がなければ本文() {
        #expect(ShareFlow.sharedText(attachmentText: nil, contentText: "本文", title: "タイトル") == "本文")
    }

    @Test func 添付が空白だけなら本文() {
        #expect(ShareFlow.sharedText(attachmentText: " \n ", contentText: "本文", title: "タイトル") == "本文")
    }

    @Test func 添付も本文もなければタイトル() {
        #expect(ShareFlow.sharedText(attachmentText: nil, contentText: "", title: "タイトル") == "タイトル")
    }

    @Test func すべて空ならnil() {
        #expect(ShareFlow.sharedText(attachmentText: nil, contentText: "  ", title: nil) == nil)
    }

    @Test func 前後の空白を取り除き混ぜない() {
        #expect(ShareFlow.sharedText(attachmentText: "  東京タワー\n", contentText: "本文", title: nil) == "東京タワー")
    }
}
