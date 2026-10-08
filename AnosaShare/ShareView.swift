import AnosaKit
import SwiftUI

/// Share Extension の画面。検索中は ProgressView だけ、選ぶ必要があるときだけ候補選択 UI を出す。
struct ShareView: View {
    @Bindable var model: ShareModel

    var body: some View {
        // 確認なしの保存では phase が .resolving のまま中身が空になるため、透明な常在ビューを土台にしてチップを必ず描画する。
        ZStack {
            Color.clear
            switch model.phase {
            case .resolving:
                if !model.isSaved {
                    ProgressView()
                }
            case .choosing:
                ShareCandidatePicker(model: model)
            }
            if model.isSaved {
                SavedConfirmationView()
                    .transition(.opacity)
            }
        }
        .animation(.default, value: model.isSaved)
        .tint(AnosaTheme.accent)
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
                    PlaceCandidateRow(candidate: candidate)
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
            .onSubmit(of: .search) {
                model.retrySearch()
            }
            .task(id: SearchRequest(text: model.searchText, attempt: model.searchAttempt)) {
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
            ContentUnavailableView {
                Label("検索できなかったよ", systemImage: "exclamationmark.magnifyingglass")
            } description: {
                Text("通信状態を確かめて、もう一度試してね。")
            } actions: {
                Button("もう一度さがす") {
                    model.retrySearch()
                }
            }
        }
    }
}

private struct SearchRequest: Equatable {
    let text: String
    let attempt: Int
}
