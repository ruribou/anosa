import Foundation

/// 検索候補から、確認なしで保存してよいかを決める。
public enum PlaceResolution: Hashable, Sendable {
    /// この候補をそのまま保存してよい。
    case single(PlaceCandidate)
    /// ユーザーに選んでもらう。
    case choose([PlaceCandidate])
    /// 候補なし。
    case none

    /// 名前が一致する候補を、クエリの座標から何メートル以内なら同じ場所とみなすか。
    public static let samePlaceRadiusMeters: Double = 200

    /// - 候補 0 件は `.none`、1 件は `.single`
    /// - 複数件で検索語がある場合
    ///   - 座標もあれば、名前が一致する候補のうち座標から `samePlaceRadiusMeters` 以内で最も近いもの
    ///   - 座標がなければ、先頭（MapKit の関連度が最も高い）候補の名前が一致するときだけ先頭
    /// - それ以外（検索語がない、一致しない）は `.choose`
    ///
    /// 名前の一致は `normalizedName(_:)` どうしの完全一致で判定する。
    public static func decide(candidates: [PlaceCandidate], query: PlaceQuery) -> PlaceResolution {
        guard let first = candidates.first else { return .none }
        if candidates.count == 1 { return .single(first) }

        guard let text = query.text.map(normalizedName(_:)), !text.isEmpty else {
            return .choose(candidates)
        }
        let matches = candidates.filter { normalizedName($0.name) == text }

        if let coordinate = query.coordinate {
            let nearest = matches
                .map { (candidate: $0, distance: $0.coordinate.distance(to: coordinate)) }
                .filter { $0.distance <= samePlaceRadiusMeters }
                .min { $0.distance < $1.distance }
            if let nearest { return .single(nearest.candidate) }
        } else if matches.first == first {
            return .single(first)
        }
        return .choose(candidates)
    }

    /// 全角・半角と大文字・小文字を同一視し、空白と記号を取り除いた名前。
    public static func normalizedName(_ name: String) -> String {
        let folded = name.folding(options: [.caseInsensitive, .widthInsensitive], locale: Locale(identifier: "ja_JP"))
        let ignored = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)
            .union(.symbols)
        return String(String.UnicodeScalarView(folded.unicodeScalars.filter { !ignored.contains($0) }))
    }
}
