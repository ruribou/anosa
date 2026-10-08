import Foundation
import Testing
@testable import AnosaKit

@MainActor
@Suite("通知アクション")
struct NotificationActionHandlerTests {
    let store: PlaceStore

    init() throws {
        store = PlaceStore(container: try AnosaStore.makeContainer(inMemory: true))
    }

    @discardableResult
    func apply(_ action: NotificationAction, _ id: UUID, now: Date = Fixtures.now) throws -> URL? {
        try NotificationActionHandler.apply(action, placeID: id, now: now, store: store, calendar: Fixtures.tokyo)
    }

    @Test func 今日はやめるで次の8時までスヌーズ() throws {
        let place = Fixtures.place()
        try store.save(place)

        #expect(try apply(.dismissToday, place.id) == nil)

        var expected = place
        expected.snoozedUntil = Fixtures.date(2026, 10, 9, 8, 0)
        #expect(try store.place(id: place.id) == expected)
    }

    @Test func 深夜の今日はやめるはその日の8時まで() throws {
        let place = Fixtures.place()
        try store.save(place)
        try apply(.dismissToday, place.id, now: Fixtures.date(2026, 10, 9, 1, 30))
        #expect(try store.place(id: place.id)?.snoozedUntil == Fixtures.date(2026, 10, 9, 8, 0))
    }

    @Test func 今日はやめるのあと判断エンジンは通知しない() throws {
        let place = Fixtures.place()
        try store.save(place)
        try apply(.dismissToday, place.id)
        let saved = try #require(try store.place(id: place.id))
        #expect(Fixtures.decide(places: [saved], now: Fixtures.now.addingTimeInterval(3600)) == nil)
    }

    @Test func もう行ったで行ったになりほかは変わらない() throws {
        let place = Fixtures.place(lastNotifiedAt: Fixtures.now)
        try store.save(place)

        #expect(try apply(.visited, place.id) == nil)

        var expected = place
        expected.status = .visited
        #expect(try store.place(id: place.id) == expected)
    }

    @Test func 行ってみるは徒歩ルートのURLを返し状態を変えない() throws {
        let place = Fixtures.place()
        try store.save(place)

        let url = try apply(.go, place.id)

        #expect(url == NotificationActionHandler.mapsWalkingURL(for: place))
        #expect(try store.place(id: place.id) == place)
    }

    @Test(arguments: NotificationAction.allCases)
    func 存在しないidは何もしない(action: NotificationAction) throws {
        let place = Fixtures.place()
        try store.save(place)
        #expect(try apply(action, UUID()) == nil)
        #expect(try store.places() == [place])
    }
}

@Suite("マップの徒歩ルート URL")
struct MapsWalkingURLTests {
    @Test func 座標を小数点以下6桁で入れる() {
        let place = Place(name: "東京タワー", latitude: 35.658581, longitude: 139.745433, savedAt: Fixtures.now)
        #expect(
            NotificationActionHandler.mapsWalkingURL(for: place).absoluteString
                == "https://maps.apple.com/?daddr=35.658581,139.745433&dirflg=w"
        )
    }

    @Test func 南半球西半球と端数の丸め() {
        let place = Place(name: "テスト", latitude: -33.8567844, longitude: -0.5, savedAt: Fixtures.now)
        let url = NotificationActionHandler.mapsWalkingURL(for: place)
        #expect(url.absoluteString == "https://maps.apple.com/?daddr=-33.856784,-0.500000&dirflg=w")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        #expect(items?.first { $0.name == "dirflg" }?.value == "w")
    }
}

@Suite("通知の識別子")
struct PlaceNotificationTests {
    @Test func アクションの文言はNotificationCopyのもの() {
        #expect(NotificationAction.go.title == NotificationCopy.actionGo)
        #expect(NotificationAction.dismissToday.title == NotificationCopy.actionDismissToday)
        #expect(NotificationAction.visited.title == NotificationCopy.actionVisited)
    }

    @Test func アクション識別子から戻せる() {
        for action in NotificationAction.allCases {
            #expect(NotificationAction(rawValue: action.identifier) == action)
        }
        #expect(Set(NotificationAction.allCases.map(\.identifier)).count == 3)
        #expect(NotificationAction(rawValue: "unknown") == nil)
    }

    @Test func userInfoの場所idを往復できる() {
        let id = UUID()
        let userInfo: [AnyHashable: Any] = PlaceNotification.userInfo(for: id)
        #expect(PlaceNotification.placeID(from: userInfo) == id)
    }

    @Test func userInfoに場所idがなければnil() {
        #expect(PlaceNotification.placeID(from: [:]) == nil)
        #expect(PlaceNotification.placeID(from: [PlaceNotification.placeIDKey: "x"]) == nil)
        #expect(PlaceNotification.placeID(from: [PlaceNotification.placeIDKey: 1]) == nil)
    }
}
