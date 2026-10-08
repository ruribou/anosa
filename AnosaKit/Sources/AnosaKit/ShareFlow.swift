import Foundation

/// Share Extension の画面遷移と入力の扱いを決める純粋関数。
public enum ShareFlow {
    public enum Step: Equatable, Sendable {
        /// 確認なしでこの候補を保存する。
        case save(PlaceCandidate)
        /// 候補選択 UI を出す。`searchText` は検索欄の初期値。
        case choose(searchText: String, candidates: [PlaceCandidate])
    }

    /// 解析結果（nil は入力から何も取れなかった）と検索候補から、最初の画面を決める。
    public static func firstStep(query: PlaceQuery?, candidates: [PlaceCandidate]) -> Step {
        guard let query else { return .choose(searchText: "", candidates: []) }
        switch PlaceResolution.decide(candidates: candidates, query: query) {
        case .single(let candidate):
            return .save(candidate)
        case .choose(let candidates):
            return .choose(searchText: query.text ?? "", candidates: candidates)
        case .none:
            return .choose(searchText: query.text ?? "", candidates: [])
        }
    }

    /// 保存する `Place.sourceURL`。クエリの URL、なければ共有された Web URL。
    public static func sourceURL(query: PlaceQuery?, sharedURL: URL?) -> URL? {
        query?.sourceURL ?? sharedURL.flatMap { isWebURL($0) ? $0 : nil }
    }

    /// テキストは 添付のテキスト → 本文（attributedContentText）→ タイトル（attributedTitle）の順で最初の 1 つを使う。
    /// 混ぜると検索語が長くなり、名前で検索できなくなるため。
    public static func sharedText(attachmentText: String?, contentText: String?, title: String?) -> String? {
        nonEmpty(attachmentText) ?? nonEmpty(contentText) ?? nonEmpty(title)
    }

    public static func isWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    public static func nonEmpty(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
