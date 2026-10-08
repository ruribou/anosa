import Foundation

/// 場所検索の候補 1 件。MapKit の型を外に出さないための値型。
public struct PlaceCandidate: Hashable, Sendable {
    public var name: String
    public var coordinate: Coordinate
    public var address: String?

    public init(name: String, coordinate: Coordinate, address: String? = nil) {
        self.name = name
        self.coordinate = coordinate
        self.address = address
    }

    /// 保存用の `Place`（ステータスは「行きたい」）を作る。
    public func makePlace(sourceURL: URL? = nil, savedAt: Date = .now) -> Place {
        Place(
            name: name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            address: address,
            sourceURL: sourceURL,
            savedAt: savedAt
        )
    }
}
