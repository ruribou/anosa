import Foundation

public struct Coordinate: Hashable, Codable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// 地球の平均半径（メートル）。
    public static let earthRadiusMeters: Double = 6_371_000

    /// ハバーサイン公式による2点間の大円距離（メートル）。
    public func distance(to other: Coordinate) -> Double {
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let dLat = (other.latitude - latitude) * .pi / 180
        let dLon = (other.longitude - longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)))
        return Coordinate.earthRadiusMeters * c
    }
}
