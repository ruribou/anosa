import Foundation

/// Share Extension / App Intent から渡された入力。
public struct SharedInput: Sendable, Hashable {
    public var url: URL?
    public var text: String?

    public init(url: URL? = nil, text: String? = nil) {
        self.url = url
        self.text = text
    }
}

/// 場所の検索に使うクエリ。`text` は検索語（場所名など）、`coordinate` は URL から読み取れた座標。
public struct PlaceQuery: Sendable, Hashable {
    public var text: String?
    public var coordinate: Coordinate?
    /// 入力に含まれていた最初の http(s) URL。保存時の `Place.sourceURL` に使う。
    public var sourceURL: URL?

    public init(text: String? = nil, coordinate: Coordinate? = nil, sourceURL: URL? = nil) {
        self.text = text
        self.coordinate = coordinate
        self.sourceURL = sourceURL
    }
}

/// 共有入力から検索クエリを取り出す。
///
/// - 地図 URL（Apple マップ / Google マップ）から名前と座標を読む。名前は URL を優先し、URL に名前がなければテキストを使う
/// - テキストは中の URL を取り除き、空白・改行を半角スペース 1 つにまとめる
/// - 地図以外の URL からはホストやパスで名前を作らない。テキストがなければ nil
public enum SharedInputParser {
    public static func query(from input: SharedInput) -> PlaceQuery? {
        let textURLs = input.text.map(urls(in:)) ?? []
        let candidates = ([input.url].compactMap { $0 } + textURLs).filter(isWebURL)
        let mapQuery = candidates.lazy.compactMap(mapQuery(from:)).first
        let text = input.text.map(cleanedText(_:)).flatMap { $0.isEmpty ? nil : $0 }

        let name = mapQuery?.name ?? text
        let coordinate = mapQuery?.coordinate
        guard name != nil || coordinate != nil else { return nil }
        return PlaceQuery(text: name, coordinate: coordinate, sourceURL: mapQuery?.url ?? candidates.first)
    }

    // MARK: - テキスト

    static func cleanedText(_ text: String) -> String {
        var remaining = text
        for range in urlRanges(in: text).reversed() {
            remaining.removeSubrange(range)
        }
        return remaining
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func urls(in text: String) -> [URL] {
        urlRanges(in: text).compactMap { URL(string: String(text[$0])) }
    }

    private static func urlRanges(in text: String) -> [Range<String.Index>] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { Range($0.range, in: text) }
    }

    private static func isWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    // MARK: - 地図 URL

    private struct MapQuery {
        var url: URL
        var name: String?
        var coordinate: Coordinate?
    }

    private static func mapQuery(from url: URL) -> MapQuery? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host?.lowercased() else { return nil }
        let result: MapQuery
        if isAppleMapsHost(host) {
            result = appleMapsQuery(url: url, components: components)
        } else if isGoogleMaps(host: host, path: components.path) {
            result = googleMapsQuery(url: url, components: components)
        } else {
            return nil
        }
        guard result.name != nil || result.coordinate != nil else { return nil }
        return result
    }

    private static func isAppleMapsHost(_ host: String) -> Bool {
        host == "maps.apple.com" || host == "maps.apple"
    }

    private static func isGoogleMaps(host: String, path: String) -> Bool {
        let labels = host.split(separator: ".")
        guard let googleIndex = labels.firstIndex(of: "google") else { return false }
        if labels.first == "maps" { return true }
        return googleIndex <= 1 && (path == "/maps" || path.hasPrefix("/maps/"))
    }

    /// name → q → address の順で名前、ll → coordinate の順で座標を読む。q が座標だけの場合は座標として扱う。
    private static func appleMapsQuery(url: URL, components: URLComponents) -> MapQuery {
        let items = queryItems(components)
        var name: String?
        var coordinate = (items["ll"] ?? items["coordinate"]).flatMap(parseCoordinate(_:))
        for key in ["name", "q", "address"] {
            guard let value = items[key] else { continue }
            if let parsed = parseCoordinate(value) {
                coordinate = coordinate ?? parsed
            } else {
                name = value
                break
            }
        }
        return MapQuery(url: url, name: name, coordinate: coordinate)
    }

    /// パスの `/maps/place/<名前>/`・`/maps/search/<名前>/` を q / query より優先し、座標は `@lat,lng` → q / query の順で読む。
    private static func googleMapsQuery(url: URL, components: URLComponents) -> MapQuery {
        let segments = components.percentEncodedPath
            .split(separator: "/")
            .map { decode(String($0)) }
        var name: String?
        var coordinate: Coordinate?

        if let index = segments.firstIndex(where: { $0 == "place" || $0 == "search" }),
           index + 1 < segments.count {
            let value = segments[index + 1]
            if let parsed = parseCoordinate(value) {
                coordinate = parsed
            } else if !value.hasPrefix("@") {
                name = value
            }
        }
        if let at = segments.first(where: { $0.hasPrefix("@") }) {
            coordinate = coordinate ?? parseCoordinate(String(at.dropFirst()))
        }

        let items = queryItems(components)
        for key in ["q", "query"] {
            guard let value = items[key] else { continue }
            if let parsed = parseCoordinate(value) {
                coordinate = coordinate ?? parsed
            } else {
                name = name ?? value
            }
        }
        return MapQuery(url: url, name: name, coordinate: coordinate)
    }

    /// `+` を空白として扱い、パーセントエンコードを戻す。空の値は除く。重複したキーは最初の値を使う。
    private static func queryItems(_ components: URLComponents) -> [String: String] {
        var result: [String: String] = [:]
        for item in components.percentEncodedQueryItems ?? [] {
            guard let raw = item.value else { continue }
            let value = decode(raw)
            guard !value.isEmpty, result[item.name] == nil else { continue }
            result[item.name] = value
        }
        return result
    }

    private static func decode(_ raw: String) -> String {
        let spaced = raw.replacingOccurrences(of: "+", with: " ")
        let decoded = spaced.removingPercentEncoding ?? spaced
        return decoded
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// "lat,lng"（3 つ目以降の要素は無視）。範囲外や数値でないものは nil。
    static func parseCoordinate(_ value: String) -> Coordinate? {
        let parts = value.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count >= 2,
              let latitude = Double(parts[0].trimmingCharacters(in: .whitespaces)),
              let longitude = Double(parts[1].trimmingCharacters(in: .whitespaces)),
              (-90...90).contains(latitude),
              (-180...180).contains(longitude) else { return nil }
        return Coordinate(latitude: latitude, longitude: longitude)
    }
}
