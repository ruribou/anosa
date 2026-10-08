import AnosaKit
import OSLog
import SwiftData
import SwiftUI

/// 手動追加。場所名で検索し、候補をタップすると保存して一言だけ出して閉じる。
struct AddPlaceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var phase: Phase = .idle
    @State private var isSaved = false
    @State private var isShowingSaveError = false
    @FocusState private var isSearchFocused: Bool

    private static let logger = Logger(subsystem: "com.example.anosa", category: "add")
    private static let searchDelay: Duration = .milliseconds(300)
    private static let dismissDelay: Duration = .seconds(1)

    private enum Phase: Equatable {
        case idle
        case searching
        case results([PlaceCandidate])
        case failed
    }

    var body: some View {
        NavigationStack {
            List(candidates, id: \.self) { candidate in
                Button {
                    save(candidate)
                } label: {
                    CandidateRow(candidate: candidate)
                }
                .foregroundStyle(.primary)
            }
            .disabled(isSaved)
            .overlay { phaseOverlay }
            .navigationTitle("場所を追加")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "場所の名前")
            .searchFocused($isSearchFocused)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
            .task(id: searchText) {
                await search(searchText)
            }
            .onAppear {
                isSearchFocused = true
            }
            .alert(SaveCopy.saveFailed, isPresented: $isShowingSaveError) {}
        }
        .overlay {
            if isSaved {
                SavedConfirmationView()
                    .transition(.opacity)
            }
        }
    }

    private var candidates: [PlaceCandidate] {
        if case .results(let candidates) = phase { candidates } else { [] }
    }

    @ViewBuilder
    private var phaseOverlay: some View {
        switch phase {
        case .idle:
            EmptyView()
        case .searching:
            ProgressView()
        case .results(let candidates) where candidates.isEmpty:
            ContentUnavailableView.search(text: searchText)
        case .results:
            EmptyView()
        case .failed:
            ContentUnavailableView("検索できなかったよ", systemImage: "exclamationmark.magnifyingglass", description: Text("通信状態を確かめて、もう一度試してね。"))
        }
    }

    /// 入力が止まってから検索する。入力が変わると `task(id:)` が前の検索をキャンセルする。
    private func search(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            phase = .idle
            return
        }
        do {
            try await Task.sleep(for: Self.searchDelay)
            phase = .searching
            let results = try await PlaceSearch.candidates(matching: trimmed)
            try Task.checkCancellation()
            phase = .results(results)
        } catch is CancellationError {
            return
        } catch {
            Self.logger.error("場所の検索に失敗しました: \(error.localizedDescription, privacy: .public)")
            phase = .failed
        }
    }

    private func save(_ candidate: PlaceCandidate) {
        guard !isSaved else { return }
        do {
            try PlaceStore(context: modelContext).save(candidate.makePlace())
        } catch {
            Self.logger.error("場所の保存に失敗しました: \(error.localizedDescription, privacy: .public)")
            isShowingSaveError = true
            return
        }
        isSearchFocused = false
        withAnimation { isSaved = true }
        Task {
            try? await Task.sleep(for: Self.dismissDelay)
            dismiss()
        }
    }
}

private struct CandidateRow: View {
    let candidate: PlaceCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(candidate.name)
            if let address = candidate.address {
                Text(address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
