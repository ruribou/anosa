import AnosaKit
import SwiftUI
import WidgetKit

struct NearbyPlaceEntry: TimelineEntry {
    let date: Date
    let content: WatchComplicationContent

    /// Smart Stack の関連度。近くにある → 0.5〜1.0（近いほど高い）、近くにない → 0.1（全部もう行った → 0）、
    /// 保存なし・現在地未取得 → 0。値は WatchComplicationContent.relevance(for:settings:) で決める。
    var relevance: TimelineEntryRelevance? {
        TimelineEntryRelevance(score: Float(content.relevance))
    }

    /// placeholder・プレビュー用の合成データ（架空の場所）。
    static let sample = NearbyPlaceEntry(
        date: .now,
        content: WatchComplicationContent(
            nearest: NearbyPlace(
                id: UUID(),
                name: "ちいさな喫茶店",
                coordinate: Coordinate(latitude: 0, longitude: 0),
                distanceMeters: 320,
                walkingMinutes: 4
            )
        )
    )

    // Preview 用。架空の位置の合成スナップショットを WatchComplicationContent(snapshot:ledger:) に通し、実際の判定で 4 状態を作る。
    static let previewNearbyShort = preview(places: [previewPlace(name: "ちいさな喫茶店", distanceMeters: 320, walkingMinutes: 4)])
    static let previewNearbyLong = preview(places: [
        previewPlace(name: "とても長い名前の架空の小さな喫茶店と古書店", distanceMeters: 180, walkingMinutes: 3),
    ])
    static let previewNoNearby = preview(places: [previewPlace(name: "遠くの架空の公園", distanceMeters: 3200, walkingMinutes: 40)])
    static let previewNoSaved = preview(places: [])
    static let previewLocationUnavailable = preview(places: nil)

    /// places が nil ならスナップショットなし（現在地未取得）。
    private static func preview(places: [NearbyPlace]?) -> NearbyPlaceEntry {
        let snapshot = places.map {
            LocationSnapshot(location: Coordinate(latitude: 0, longitude: 0), capturedAt: .now, places: $0)
        }
        return NearbyPlaceEntry(date: .now, content: WatchComplicationContent(snapshot: snapshot, ledger: WatchVisitedLedger()))
    }

    private static func previewPlace(name: String, distanceMeters: Double, walkingMinutes: Int) -> NearbyPlace {
        NearbyPlace(
            id: UUID(),
            name: name,
            coordinate: Coordinate(latitude: 0, longitude: 0),
            distanceMeters: distanceMeters,
            walkingMinutes: walkingMinutes
        )
    }
}

/// App Group のスナップショットと台帳から作る。Watch アプリが受信時に reloadAllTimelines するため、自分では更新しない。
struct NearbyPlaceProvider: TimelineProvider {
    func placeholder(in context: Context) -> NearbyPlaceEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping (NearbyPlaceEntry) -> Void) {
        completion(context.isPreview ? .sample : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NearbyPlaceEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> NearbyPlaceEntry {
        let content = WatchComplicationContent(
            snapshot: LocationSnapshotStore.shared().load(),
            ledger: WatchVisitedLedgerStore.shared().load()
        )
        return NearbyPlaceEntry(date: .now, content: content)
    }
}

struct NearbyPlaceWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NearbyPlaceEntry

    var body: some View {
        content
            .containerBackground(.fill.tertiary, for: .widget)
    }

    /// 状態ごとのシンボル。近くにない（静かな待機）も近くにあると同じピンにし、数字・名前の有無で見分ける。
    private static func symbol(for state: WatchComplicationContent.State) -> String {
        switch state {
        case .nearby, .noNearbyPlaces:
            "mappin"
        case .noSavedPlaces:
            "plus"
        case .locationUnavailable:
            "location.slash"
        }
    }

    @ViewBuilder
    private var content: some View {
        let content = entry.content
        let symbol = Self.symbol(for: content.state)
        switch family {
        case .accessoryInline:
            // 残す: シンボル＋1 行（名前・徒歩分、名前が長ければ徒歩分だけ）。捨てる: 距離・一言。
            Label(content.inlineText, systemImage: symbol)
        case .accessoryCircular:
            // 残す: ピン＋徒歩分（近くにあるとき）／シンボルだけ（それ以外）。捨てる: 名前・距離・状態の文言。
            ZStack {
                AccessoryWidgetBackground()
                if let place = content.place {
                    VStack(spacing: 0) {
                        Image(systemName: symbol)
                        Text("\(place.walkingMinutes)分")
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .padding(4)
                    .widgetAccentable()
                } else {
                    Image(systemName: symbol)
                        .font(.title3)
                        .widgetAccentable()
                }
            }
        case .accessoryCorner:
            // 残す: シンボル＋徒歩分か短い状態。捨てる: 名前・距離。近くにないときはラベルも出さない。
            if let label = content.cornerLabel {
                Image(systemName: symbol)
                    .font(.title3)
                    .widgetAccentable()
                    .widgetLabel {
                        Text(label)
                    }
            } else {
                Image(systemName: symbol)
                    .font(.title3)
                    .widgetAccentable()
            }
        default:
            // accessoryRectangular
            if let place = content.place {
                // 残す（優先順）: 名前 → 徒歩分・距離 → 「近くにあるよ」。入らなければ一言から捨て、長い名前は 2 行まで（縮小→末尾で切る）。
                rectangularNearby(name: place.name, detail: [content.walkingText, content.distanceText].compactMap(\.self).joined(separator: "・"))
            } else {
                // 残す: シンボル＋状態の一言（2〜3 行まで折り返す）。捨てる: 名前・距離。
                Label {
                    Text(content.rectangularMessage ?? "")
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                } icon: {
                    Image(systemName: symbol)
                        .widgetAccentable()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// ViewThatFits は子の理想サイズ（Text は折り返さない幅）で判定するので、名前が 1 行に入らなければ次の候補へ進む。
    private func rectangularNearby(name: String, detail: String) -> some View {
        ViewThatFits(in: [.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                Label(WidgetCopy.Watch.nearbyCaption, systemImage: "mappin")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                rectangularName(name, lineLimit: 1)
                rectangularDetail(detail)
            }
            VStack(alignment: .leading, spacing: 0) {
                rectangularName(name, lineLimit: 1)
                rectangularDetail(detail)
            }
            VStack(alignment: .leading, spacing: 0) {
                rectangularName(name, lineLimit: 2)
                    .minimumScaleFactor(0.8)
                    .truncationMode(.tail)
                rectangularDetail(detail)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rectangularName(_ name: String, lineLimit: Int) -> some View {
        Text(name)
            .font(.headline)
            .lineLimit(lineLimit)
            .widgetAccentable()
    }

    private func rectangularDetail(_ detail: String) -> some View {
        Text(detail)
            .font(.caption)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .widgetAccentable()
    }
}

struct NearbyPlaceWidget: Widget {
    static let kind = "AnosaWatchNearbyPlace"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: NearbyPlaceProvider()) { entry in
            NearbyPlaceWidgetView(entry: entry)
        }
        .configurationDisplayName("近くの行きたい場所")
        .description("いちばん近い行きたい場所と、歩いてかかる時間を表示します。")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
    }
}

// 4 ファミリーそれぞれで、近くにある（短い名前・長い名前）・近くにない・保存なし・現在地未取得を確認する。
#Preview(as: .accessoryRectangular) {
    NearbyPlaceWidget()
} timeline: {
    NearbyPlaceEntry.previewNearbyShort
    NearbyPlaceEntry.previewNearbyLong
    NearbyPlaceEntry.previewNoNearby
    NearbyPlaceEntry.previewNoSaved
    NearbyPlaceEntry.previewLocationUnavailable
}

#Preview(as: .accessoryCircular) {
    NearbyPlaceWidget()
} timeline: {
    NearbyPlaceEntry.previewNearbyShort
    NearbyPlaceEntry.previewNearbyLong
    NearbyPlaceEntry.previewNoNearby
    NearbyPlaceEntry.previewNoSaved
    NearbyPlaceEntry.previewLocationUnavailable
}

#Preview(as: .accessoryCorner) {
    NearbyPlaceWidget()
} timeline: {
    NearbyPlaceEntry.previewNearbyShort
    NearbyPlaceEntry.previewNearbyLong
    NearbyPlaceEntry.previewNoNearby
    NearbyPlaceEntry.previewNoSaved
    NearbyPlaceEntry.previewLocationUnavailable
}

#Preview(as: .accessoryInline) {
    NearbyPlaceWidget()
} timeline: {
    NearbyPlaceEntry.previewNearbyShort
    NearbyPlaceEntry.previewNearbyLong
    NearbyPlaceEntry.previewNoNearby
    NearbyPlaceEntry.previewNoSaved
    NearbyPlaceEntry.previewLocationUnavailable
}
