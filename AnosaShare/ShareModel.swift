import AnosaKit
import Foundation
import Observation
import OSLog

enum ShareOutcome {
    case completed
    case cancelled
}

/// Share Extension の状態。解析 → 検索 → 保存（または候補選択）→ 閉じる。
@MainActor
@Observable
final class ShareModel {
    enum Phase: Equatable {
        case resolving
        case choosing
    }

    enum SearchState: Equatable {
        case idle
        case searching
        case results([PlaceCandidate])
        case failed
    }

    private(set) var phase: Phase = .resolving
    private(set) var searchState: SearchState = .idle
    private(set) var isSaved = false
    var searchText = ""
    var isShowingSaveError = false

    @ObservationIgnored private var query: PlaceQuery?
    @ObservationIgnored private var sharedURL: URL?
    /// 座標だけのクエリで逆ジオコーディングした候補。検索欄が空のときに出す。
    @ObservationIgnored private var emptyTextCandidates: [PlaceCandidate] = []
    @ObservationIgnored private var lastSearchedText: String?
    /// ModelContainer を保持し続けるため、PlaceStore を使い回す。
    @ObservationIgnored private var store: PlaceStore?
    @ObservationIgnored private let finish: @MainActor (ShareOutcome) -> Void

    private static let logger = Logger(subsystem: "com.example.anosa", category: "share")
    private static let searchDelay: Duration = .milliseconds(300)
    private static let dismissDelay: Duration = .seconds(1)

    init(finish: @escaping @MainActor (ShareOutcome) -> Void) {
        self.finish = finish
    }

    var candidates: [PlaceCandidate] {
        if case .results(let candidates) = searchState { candidates } else { [] }
    }

    func start(with input: SharedInput) async {
        sharedURL = input.url
        let query = SharedInputParser.query(from: input)
        self.query = query

        var candidates: [PlaceCandidate] = []
        if let query {
            do {
                candidates = try await PlaceSearch.candidates(for: query)
            } catch {
                Self.logger.error("場所の検索に失敗しました: \(error.localizedDescription, privacy: .public)")
                showChooser(searchText: query.text ?? "", state: .failed)
                return
            }
        }

        switch ShareFlow.firstStep(query: query, candidates: candidates) {
        case .save(let candidate):
            save(candidate)
        case .choose(let searchText, let candidates):
            if query != nil, ShareFlow.nonEmpty(searchText) == nil {
                emptyTextCandidates = candidates
            }
            showChooser(searchText: searchText, state: query == nil ? .idle : .results(candidates))
        }
    }

    /// 検索欄の入力が止まってから検索する。入力が変わると `task(id:)` が前の検索をキャンセルする。
    func search(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != lastSearchedText else { return }
        guard !trimmed.isEmpty else {
            lastSearchedText = trimmed
            searchState = emptyTextCandidates.isEmpty ? .idle : .results(emptyTextCandidates)
            return
        }
        do {
            try await Task.sleep(for: Self.searchDelay)
            searchState = .searching
            let results = try await PlaceSearch.candidates(matching: trimmed, near: query?.coordinate)
            try Task.checkCancellation()
            lastSearchedText = trimmed
            searchState = .results(results)
        } catch is CancellationError {
            return
        } catch {
            Self.logger.error("場所の検索に失敗しました: \(error.localizedDescription, privacy: .public)")
            lastSearchedText = trimmed
            searchState = .failed
        }
    }

    func save(_ candidate: PlaceCandidate) {
        guard !isSaved else { return }
        let place = candidate.makePlace(sourceURL: ShareFlow.sourceURL(query: query, sharedURL: sharedURL))
        do {
            let store = try store ?? PlaceStore(container: AnosaStore.makeContainer())
            self.store = store
            try store.save(place)
        } catch {
            Self.logger.error("場所の保存に失敗しました: \(error.localizedDescription, privacy: .public)")
            if phase == .resolving {
                // 確認なしの保存で失敗したときも、選び直しと閉じる手段を残す。
                showChooser(searchText: query?.text ?? "", state: .results([candidate]))
            }
            isShowingSaveError = true
            return
        }
        isSaved = true
        Task {
            try? await Task.sleep(for: Self.dismissDelay)
            finish(.completed)
        }
    }

    func cancel() {
        finish(.cancelled)
    }

    private func showChooser(searchText: String, state: SearchState) {
        self.searchText = searchText
        lastSearchedText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        searchState = state
        phase = .choosing
    }
}
