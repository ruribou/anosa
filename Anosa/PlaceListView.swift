import AnosaKit
import OSLog
import SwiftData
import SwiftUI

/// 保存済みの場所の一覧（1 ステータス分）。並べ替え・編集・地図表示は持たない。
struct PlaceListView: View {
    let status: PlaceStatus
    let onAdd: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Query private var entities: [PlaceEntity]

    private static let logger = Logger(subsystem: "com.example.anosa", category: "list")

    init(status: PlaceStatus, onAdd: (() -> Void)? = nil) {
        self.status = status
        self.onAdd = onAdd
        let rawValue = status.rawValue
        _entities = Query(
            filter: #Predicate<PlaceEntity> { $0.statusRawValue == rawValue },
            sort: \PlaceEntity.savedAt,
            order: .reverse
        )
    }

    var body: some View {
        List {
            ForEach(entities) { entity in
                PlaceRow(place: entity.place)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("削除", systemImage: "trash", role: .destructive) {
                            perform { try $0.delete(id: entity.id) }
                        }
                        ForEach(PlaceStatus.allCases.filter { $0 != status }, id: \.self) { target in
                            Button(target.moveActionTitle, systemImage: target.systemImage) {
                                perform { try $0.setStatus(target, for: entity.id) }
                            }
                        }
                    }
            }
        }
        .overlay {
            if entities.isEmpty {
                emptyView
            }
        }
    }

    @ViewBuilder
    private var emptyView: some View {
        switch status {
        case .wantToGo:
            ContentUnavailableView {
                Label("保存したら、忘れていい。", systemImage: "mappin.and.ellipse")
            } description: {
                Text("ほかのアプリの共有メニューからも保存できるよ。近くに来たら教えるね。")
            } actions: {
                if let onAdd {
                    Button("場所を追加", systemImage: "plus") {
                        onAdd()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        case .visited:
            ContentUnavailableView("行った場所はまだないよ", systemImage: "checkmark")
        case .archived:
            ContentUnavailableView("アーカイブした場所はないよ", systemImage: "archivebox")
        }
    }

    private func perform(_ operation: (PlaceStore) throws -> Void) {
        do {
            try operation(PlaceStore(context: modelContext))
        } catch {
            Self.logger.error("場所の更新に失敗しました: \(error.localizedDescription, privacy: .public)")
        }
    }
}

private struct PlaceRow: View {
    let place: Place

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(place.name)
            if let address = place.address {
                Text(address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
