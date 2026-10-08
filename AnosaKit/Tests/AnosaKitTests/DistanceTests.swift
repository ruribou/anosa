import Foundation
import Testing
@testable import AnosaKit

@Suite("距離と徒歩分数")
struct DistanceTests {
    @Test func 子午線上の緯度1度は約111195m() {
        let a = Coordinate(latitude: 35, longitude: 139)
        let b = Coordinate(latitude: 36, longitude: 139)
        #expect(abs(a.distance(to: b) - 111_194.93) < 0.1)
    }

    @Test func 赤道上の経度1度は約111195m() {
        let a = Coordinate(latitude: 0, longitude: 0)
        let b = Coordinate(latitude: 0, longitude: 1)
        #expect(abs(a.distance(to: b) - 111_194.93) < 0.1)
    }

    @Test func 高緯度では経度1度の距離が縮む() {
        // 緯度60度では cos(60°)=0.5 倍程度
        let a = Coordinate(latitude: 60, longitude: 0)
        let b = Coordinate(latitude: 60, longitude: 1)
        #expect(abs(a.distance(to: b) - 55_596) < 50)
    }

    @Test func 東京駅から北へ500mの合成点() {
        let target = Fixtures.north(meters: 500)
        #expect(abs(Fixtures.origin.distance(to: target) - 500) < 0.01)
    }

    @Test func 同一地点は0で距離は対称() {
        let a = Fixtures.origin
        let b = Coordinate(latitude: 35.689487, longitude: 139.691706)
        #expect(a.distance(to: a) == 0)
        #expect(abs(a.distance(to: b) - b.distance(to: a)) < 1e-6)
    }

    @Test func 通知距離の内側は対象_外側は対象外() {
        #expect(Fixtures.decide(places: [Fixtures.place(metersNorth: 499)]) != nil)
        #expect(Fixtures.decide(places: [Fixtures.place(metersNorth: 501)]) == nil)
    }

    @Test func 通知距離ちょうどは対象() {
        var settings = AnosaSettings.default
        settings.notificationRadiusMeters = 0
        #expect(Fixtures.decide(places: [Fixtures.place(metersNorth: 0)], settings: settings) != nil)
    }

    @Test func 通知距離の設定を変えると判定が変わる() {
        var settings = AnosaSettings.default
        settings.notificationRadiusMeters = 1000
        #expect(Fixtures.decide(places: [Fixtures.place(metersNorth: 800)], settings: settings) != nil)
    }

    @Test(arguments: [
        (0.0, 1), (1.0, 1), (80.0, 1), (81.0, 2), (400.0, 5), (401.0, 6),
    ])
    func 徒歩分数は80m毎分で切り上げ_最小1分(meters: Double, minutes: Int) {
        #expect(AnosaSettings.default.walkingMinutes(forDistance: meters) == minutes)
    }

    @Test func 候補に距離と徒歩分数が入る() throws {
        let candidate = try #require(Fixtures.decide(places: [Fixtures.place(metersNorth: 250)]))
        #expect(abs(candidate.distanceMeters - 250) < 0.01)
        #expect(candidate.walkingMinutes == 4)
    }
}
