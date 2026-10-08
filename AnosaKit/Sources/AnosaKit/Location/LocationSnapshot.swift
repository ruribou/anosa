import Foundation

/// 最後の現在地と近い「行きたい」場所。ウィジェット・Watch が App Group から読む。
public struct LocationSnapshot: Hashable, Codable, Sendable {
    public var location: Coordinate
    public var capturedAt: Date
    /// 近い順。
    public var places: [NearbyPlace]

    public init(location: Coordinate, capturedAt: Date, places: [NearbyPlace]) {
        self.location = location
        self.capturedAt = capturedAt
        self.places = places
    }

    public static let defaultLimit = 5

    /// `status == .wantToGo` の場所を近い順（同距離は id 昇順）に `limit` 件まで入れる。
    public static func make(
        location: Coordinate,
        capturedAt: Date,
        places: [Place],
        settings: AnosaSettings = .default,
        limit: Int = defaultLimit
    ) -> LocationSnapshot {
        let nearby = NearestPlaces.wantToGo(near: location, places: places, limit: limit).map { entry in
            NearbyPlace(
                id: entry.place.id,
                name: entry.place.name,
                coordinate: entry.place.coordinate,
                distanceMeters: entry.distanceMeters,
                walkingMinutes: settings.walkingMinutes(forDistance: entry.distanceMeters)
            )
        }
        return LocationSnapshot(location: location, capturedAt: capturedAt, places: nearby)
    }
}

public struct NearbyPlace: Hashable, Codable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var coordinate: Coordinate
    public var distanceMeters: Double
    public var walkingMinutes: Int

    public init(id: UUID, name: String, coordinate: Coordinate, distanceMeters: Double, walkingMinutes: Int) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.distanceMeters = distanceMeters
        self.walkingMinutes = walkingMinutes
    }
}

/// スナップショットを App Group の UserDefaults に JSON で保存する。
public struct LocationSnapshotStore {
    public static let defaultKey = "locationSnapshot"

    public let defaults: UserDefaults
    public let key: String

    public init(defaults: UserDefaults, key: String = defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    /// App Group の suite。取れなければ `.standard`（この場合アプリと拡張で共有されない）。
    public static func shared() -> LocationSnapshotStore {
        LocationSnapshotStore(defaults: SharedDefaults.make())
    }

    public func save(_ snapshot: LocationSnapshot) throws {
        defaults.set(try JSONEncoder().encode(snapshot), forKey: key)
    }

    /// 保存がない・読めないときは nil。
    public func load() -> LocationSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(LocationSnapshot.self, from: data)
    }
}
