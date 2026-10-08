import CoreLocation
import Foundation
import MapKit

/// MapKit で場所を検索し、`PlaceCandidate` にして返す。Share Extension・手動追加・App Intent で共通に使う。
public enum PlaceSearch {
    public static let defaultLimit = 10
    /// 座標つきで検索するときに寄せる範囲（一辺のメートル）。
    public static let nearbySpanMeters: Double = 1_000

    /// 検索語があれば名前で検索し（座標があればその周辺に寄せる）、座標だけなら逆ジオコーディングする。
    public static func candidates(for query: PlaceQuery, limit: Int = defaultLimit) async throws -> [PlaceCandidate] {
        if let text = query.text, !text.isEmpty {
            return try await candidates(matching: text, near: query.coordinate, limit: limit)
        }
        if let coordinate = query.coordinate {
            return try await candidates(at: coordinate, limit: limit)
        }
        return []
    }

    /// MKLocalSearch での名前検索。見つからなければ空配列を返す。
    public static func candidates(matching text: String, near coordinate: Coordinate? = nil, limit: Int = defaultLimit) async throws -> [PlaceCandidate] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        if let coordinate {
            request.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude),
                latitudinalMeters: nearbySpanMeters,
                longitudinalMeters: nearbySpanMeters
            )
        }

        let mapItems: [MKMapItem]
        do {
            mapItems = try await MKLocalSearch(request: request).start().mapItems
        } catch let error as MKError where error.code == .placemarkNotFound {
            return []
        }
        return Array(mapItems.compactMap { candidate(from: $0) }.prefix(limit))
    }

    /// 座標だけのとき。逆ジオコーディングで名前（なければ短い住所）を付け、座標は渡されたものを使う。
    /// 名前も住所も取れなければ候補にしない。
    public static func candidates(at coordinate: Coordinate, limit: Int = defaultLimit) async throws -> [PlaceCandidate] {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else { return [] }

        let mapItems: [MKMapItem]
        do {
            mapItems = try await request.mapItems
        } catch let error as MKError where error.code == .placemarkNotFound {
            return []
        }
        let candidates = mapItems.compactMap { item -> PlaceCandidate? in
            guard let name = nonEmpty(item.name) ?? nonEmpty(item.address?.shortAddress) else { return nil }
            return PlaceCandidate(name: name, coordinate: coordinate, address: address(of: item))
        }
        return Array(candidates.prefix(limit))
    }

    static func candidate(from item: MKMapItem) -> PlaceCandidate? {
        guard let name = nonEmpty(item.name) else { return nil }
        let location = item.location.coordinate
        return PlaceCandidate(
            name: name,
            coordinate: Coordinate(latitude: location.latitude, longitude: location.longitude),
            address: address(of: item)
        )
    }

    /// 1 行の住所（国・地域名を除く）。取れなければ MKAddress の住所。
    static func address(of item: MKMapItem) -> String? {
        nonEmpty(item.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true))
            ?? nonEmpty(item.address?.shortAddress)
            ?? nonEmpty(item.address?.fullAddress)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
