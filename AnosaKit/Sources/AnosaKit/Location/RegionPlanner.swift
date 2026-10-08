import Foundation

/// リージョンの識別子。場所の id から決定的に作り、逆変換できる。
public enum RegionIdentifier {
    public static let prefix = "place."

    public static func make(for placeID: UUID) -> String {
        prefix + placeID.uuidString
    }

    /// `make(for:)` で作った識別子でなければ nil。
    public static func placeID(from identifier: String) -> UUID? {
        guard identifier.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(identifier.dropFirst(prefix.count)))
    }
}

/// 監視する円形リージョン 1 件。
public struct PlannedRegion: Hashable, Sendable {
    public var identifier: String
    public var placeID: UUID
    public var center: Coordinate
    public var radiusMeters: Double
    /// 計画時点の現在地からの距離（メートル）。
    public var distanceMeters: Double

    public init(identifier: String, placeID: UUID, center: Coordinate, radiusMeters: Double, distanceMeters: Double) {
        self.identifier = identifier
        self.placeID = placeID
        self.center = center
        self.radiusMeters = radiusMeters
        self.distanceMeters = distanceMeters
    }
}

/// 監視の入れ替え計画。
public struct RegionPlan: Hashable, Sendable {
    /// 入れ替え後に監視しているべきリージョン（近い順）。
    public var desired: [PlannedRegion]
    /// 新たに監視を始めるリージョン（近い順）。
    public var toAdd: [PlannedRegion]
    /// 監視をやめる識別子（昇順）。
    public var toRemove: [String]

    public init(desired: [PlannedRegion], toAdd: [PlannedRegion], toRemove: [String]) {
        self.desired = desired
        self.toAdd = toAdd
        self.toRemove = toRemove
    }
}

public enum RegionPlanner {
    /// 現在地に近い「行きたい」の場所を上限件数まで選び、今の監視との差分を返す。
    /// 監視中の識別子のうち選ばれなかったもの（Anosa の形式でないものも含む）はすべて外す。
    public static func plan(
        currentLocation: Coordinate,
        places: [Place],
        monitoredIdentifiers: Set<String>,
        limit: Int,
        radiusMeters: Double
    ) -> RegionPlan {
        let desired = NearestPlaces.wantToGo(near: currentLocation, places: places, limit: limit).map { entry in
            PlannedRegion(
                identifier: RegionIdentifier.make(for: entry.place.id),
                placeID: entry.place.id,
                center: entry.place.coordinate,
                radiusMeters: radiusMeters,
                distanceMeters: entry.distanceMeters
            )
        }
        let desiredIdentifiers = Set(desired.map(\.identifier))
        return RegionPlan(
            desired: desired,
            toAdd: desired.filter { !monitoredIdentifiers.contains($0.identifier) },
            toRemove: monitoredIdentifiers.subtracting(desiredIdentifiers).sorted()
        )
    }

    /// 上限と半径を `settings` から取る。
    public static func plan(
        currentLocation: Coordinate,
        places: [Place],
        monitoredIdentifiers: Set<String>,
        settings: AnosaSettings
    ) -> RegionPlan {
        plan(
            currentLocation: currentLocation,
            places: places,
            monitoredIdentifiers: monitoredIdentifiers,
            limit: settings.monitoredRegionLimit,
            radiusMeters: settings.regionRadiusMeters
        )
    }
}
