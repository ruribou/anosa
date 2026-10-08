import Foundation
import SwiftData

/// `Place` の SwiftData 永続化モデル。アプリ側のロジックは `Place` 値型で扱い、保存時だけこの型に変換する。
@Model
public final class PlaceEntity {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var address: String?
    public var sourceURL: URL?
    public var note: String?
    public var savedAt: Date
    /// `PlaceStatus.rawValue`。述語で絞り込めるように文字列で保存する。
    public var statusRawValue: String
    public var lastNotifiedAt: Date?
    public var snoozedUntil: Date?
    public var notifiedCount: Int
    /// `OpeningHours` の JSON。
    public var openingHoursData: Data?

    public init(_ place: Place) {
        id = place.id
        name = place.name
        latitude = place.latitude
        longitude = place.longitude
        address = place.address
        sourceURL = place.sourceURL
        note = place.note
        savedAt = place.savedAt
        statusRawValue = place.status.rawValue
        lastNotifiedAt = place.lastNotifiedAt
        snoozedUntil = place.snoozedUntil
        notifiedCount = place.notifiedCount
        openingHoursData = Self.encode(place.openingHours)
    }

    /// `id` 以外の項目を `place` で上書きする。
    public func update(from place: Place) {
        name = place.name
        latitude = place.latitude
        longitude = place.longitude
        address = place.address
        sourceURL = place.sourceURL
        note = place.note
        savedAt = place.savedAt
        statusRawValue = place.status.rawValue
        lastNotifiedAt = place.lastNotifiedAt
        snoozedUntil = place.snoozedUntil
        notifiedCount = place.notifiedCount
        openingHoursData = Self.encode(place.openingHours)
    }

    /// 未知の status は「行きたい」、読めない営業時間は未設定として扱う。
    public var status: PlaceStatus {
        get { PlaceStatus(rawValue: statusRawValue) ?? .wantToGo }
        set { statusRawValue = newValue.rawValue }
    }

    public var place: Place {
        Place(
            id: id,
            name: name,
            latitude: latitude,
            longitude: longitude,
            address: address,
            sourceURL: sourceURL,
            note: note,
            savedAt: savedAt,
            status: status,
            lastNotifiedAt: lastNotifiedAt,
            snoozedUntil: snoozedUntil,
            notifiedCount: notifiedCount,
            openingHours: openingHoursData.flatMap { try? JSONDecoder().decode(OpeningHours.self, from: $0) }
        )
    }

    private static func encode(_ openingHours: OpeningHours?) -> Data? {
        guard let openingHours else { return nil }
        return try? JSONEncoder().encode(openingHours)
    }
}
