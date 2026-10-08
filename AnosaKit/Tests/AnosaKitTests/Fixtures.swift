import Foundation
@testable import AnosaKit

enum Fixtures {
    static let tokyo: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }()

    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// 東京駅付近（公知のランドマーク）。
    static let origin = Coordinate(latitude: 35.681236, longitude: 139.767125)

    static let metersPerDegreeLatitude = Coordinate.earthRadiusMeters * .pi / 180

    /// 2026-10-08（木）12:00 JST
    static let now = date(2026, 10, 8, 12, 0)

    static let day: TimeInterval = 24 * 60 * 60

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0, calendar: Calendar = tokyo) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    /// origin から真北に `meters` 離れた座標。
    static func north(of base: Coordinate = origin, meters: Double) -> Coordinate {
        Coordinate(latitude: base.latitude + meters / metersPerDegreeLatitude, longitude: base.longitude)
    }

    static func place(
        id: UUID = UUID(),
        name: String = "テストの場所",
        metersNorth: Double = 100,
        savedAt: Date = now.addingTimeInterval(-day),
        status: PlaceStatus = .wantToGo,
        lastNotifiedAt: Date? = nil,
        snoozedUntil: Date? = nil,
        openingHours: OpeningHours? = nil
    ) -> Place {
        let coordinate = north(meters: metersNorth)
        return Place(
            id: id,
            name: name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            savedAt: savedAt,
            status: status,
            lastNotifiedAt: lastNotifiedAt,
            snoozedUntil: snoozedUntil,
            openingHours: openingHours
        )
    }

    static func decide(
        places: [Place],
        history: [NotificationRecord] = [],
        now: Date = now,
        location: Coordinate = origin,
        settings: AnosaSettings = .default,
        openingHours: any OpeningHoursProvider = AlwaysOpenProvider(),
        calendar: Calendar = tokyo
    ) -> NotificationCandidate? {
        DecisionEngine.placeToNotify(
            currentLocation: location,
            now: now,
            places: places,
            history: history,
            settings: settings,
            openingHours: openingHours,
            calendar: calendar
        )
    }
}

/// 決定的な乱数（SplitMix64）。
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// テストごとに使い捨てる UserDefaults の suite。解放時に中身を消す。
final class TemporaryDefaults {
    let suiteName = "AnosaKitTests.\(UUID().uuidString)"
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }
}
