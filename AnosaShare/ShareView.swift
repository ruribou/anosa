import AnosaKit
import SwiftUI

/// Share Extension の画面。検索中は ProgressView だけ、選ぶ必要があるときだけ候補選択 UI を出す。
struct ShareView: View {
    @Bindable var model: ShareModel

    var body: some View {
        Group {
            switch model.phase {
            case .resolving:
                if !model.isSaved {
                    ProgressView()
                }
            case .choosing:
                ShareCandidatePicker(model: model)
            }
        }
        .overlay {
            if model.isSaved {
                SavedConfirmationView()
                    .transition(.opacity)
            }
        }
        .animation(.default, value: model.isSaved)
    }
}

private struct ShareCandidatePicker: View {
    @Bindable var model: ShareModel

    var body: some View {
        NavigationStack {
            List(model.candidates, id: \.self) { candidate in
                Button {
                    model.save(candidate)
                } label: {
                    CandidateRow(candidate: candidate)
                }
                .foregroundStyle(.primary)
            }
            .disabled(model.isSaved)
            .overlay { stateOverlay }
            .navigationTitle("場所を選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $model.searchText, prompt: "場所の名前")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", role: .cancel) {
                        model.cancel()
                    }
                }
            }
            .task(id: model.searchText) {
                await model.search(model.searchText)
            }
            .alert(SaveCopy.saveFailed, isPresented: $model.isShowingSaveError) {}
        }
    }

    @ViewBuilder
    private var stateOverlay: some View {
        switch model.searchState {
        case .idle:
            ContentUnavailableView("場所の名前で探してね", systemImage: "magnifyingglass")
        case .searching:
            ProgressView()
        case .results(let candidates) where candidates.isEmpty:
            ContentUnavailableView(SaveCopy.notFound, systemImage: "mappin.slash")
        case .results:
            EmptyView()
        case .failed:
            ContentUnavailableView("検索できなかったよ", systemImage: "exclamationmark.magnifyingglass", description: Text("通信状態を確かめて、もう一度試してね。"))
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
