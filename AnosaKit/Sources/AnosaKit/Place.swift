import Foundation

public enum PlaceStatus: String, Hashable, Codable, Sendable, CaseIterable {
    /// 行きたい
    case wantToGo
    /// 行った
    case visited
    /// アーカイブ
    case archived
}

public struct Place: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var address: String?
    public var sourceURL: URL?
    public var note: String?
    public var savedAt: Date
    public var status: PlaceStatus
    public var lastNotifiedAt: Date?
    public var snoozedUntil: Date?
    public var notifiedCount: Int
    public var openingHours: OpeningHours?

    public init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        address: String? = nil,
        sourceURL: URL? = nil,
        note: String? = nil,
        savedAt: Date,
        status: PlaceStatus = .wantToGo,
        lastNotifiedAt: Date? = nil,
        snoozedUntil: Date? = nil,
        notifiedCount: Int = 0,
        openingHours: OpeningHours? = nil
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.sourceURL = sourceURL
        self.note = note
        self.savedAt = savedAt
        self.status = status
        self.lastNotifiedAt = lastNotifiedAt
        self.snoozedUntil = snoozedUntil
        self.notifiedCount = notifiedCount
        self.openingHours = openingHours
    }

    public var coordinate: Coordinate {
        Coordinate(latitude: latitude, longitude: longitude)
    }
}

public struct NotificationRecord: Hashable, Codable, Sendable {
    public var placeID: UUID
    public var notifiedAt: Date

    public init(placeID: UUID, notifiedAt: Date) {
        self.placeID = placeID
        self.notifiedAt = notifiedAt
    }
}
