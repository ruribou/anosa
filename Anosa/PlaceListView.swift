import AnosaKit
import OSLog
import SwiftData
import SwiftUI

/// 保存済みの場所の一覧（1 ステータス分）。並べ替え・編集・地図表示は持たない。
struct PlaceListView: View {
    let status: PlaceStatus
    let onAdd: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var entities: [PlaceEntity]
    /// 距離・徒歩分を添えるための最後のスナップショット（「行きたい」の近い数件だけ）。
    @State private var snapshot: LocationSnapshot?

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
                PlaceRow(detail: PlaceRowDetail(place: entity.place, snapshot: snapshot, now: .now))
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
        .task(id: status) {
            loadSnapshot()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                loadSnapshot()
            }
        }
    }

    /// 距離を出すのは「行きたい」だけなので、ほかのステータスでは読まない。
    private func loadSnapshot() {
        snapshot = status == .wantToGo ? LocationSnapshotStore.shared().load() : nil
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
                    .buttonStyle(.glassProminent)
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
    let detail: PlaceRowDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(detail.name)
            if let address = detail.address, !address.isEmpty {
                Text(address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            hints
                .font(.footnote)
                .foregroundStyle(.secondary)
                .imageScale(.small)
                .labelStyle(CompactHintLabelStyle())
                .padding(.top, 2)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(detail.accessibilityLabel)
    }

    /// 思い出すきっかけの控えめな 1 行。横に収まらない（大きい文字）ときは縦に並べる。
    @ViewBuilder
    private var hints: some View {
        if let distanceText = detail.distanceText {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    savedAgo
                    distance(distanceText)
                }
                VStack(alignment: .leading, spacing: 2) {
                    savedAgo
                    distance(distanceText)
                }
            }
        } else {
            savedAgo
        }
    }

    private var savedAgo: some View {
        Label(detail.savedAgoText, systemImage: "clock")
    }

    private func distance(_ text: String) -> some View {
        Label(text, systemImage: "figure.walk")
    }
}

/// 控えめな 1 行のラベル。標準の Label はシンボルと文字の間が広く、項目がばらけて見えるため詰める。
private struct CompactHintLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            configuration.icon
            configuration.title
        }
    }
}
