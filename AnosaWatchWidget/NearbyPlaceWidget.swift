import AnosaKit
import SwiftUI
import WidgetKit

struct NearbyPlaceEntry: TimelineEntry {
    let date: Date
    let content: WatchComplicationContent

    var relevance: TimelineEntryRelevance? {
        TimelineEntryRelevance(score: Float(content.relevance))
    }

    /// placeholder・プレビュー用の合成データ（架空の場所）。
    static let sample = NearbyPlaceEntry(
        date: .now,
        content: WatchComplicationContent(
            place: NearbyPlace(
                id: UUID(),
                name: "ちいさな喫茶店",
                coordinate: Coordinate(latitude: 0, longitude: 0),
                distanceMeters: 320,
                walkingMinutes: 4
            )
        )
    )

    static let empty = NearbyPlaceEntry(date: .now, content: WatchComplicationContent(place: nil))
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

    private static let symbol = "figure.walk"

    var body: some View {
        content
            .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        let content = entry.content
        switch family {
        case .accessoryInline:
            Label(content.inlineText, systemImage: Self.symbol)
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                if let place = content.place {
                    VStack(spacing: 0) {
                        Image(systemName: Self.symbol)
                        Text("\(place.walkingMinutes)分")
                    }
                    .widgetAccentable()
                } else {
                    Image(systemName: Self.symbol)
                        .widgetAccentable()
                }
            }
        case .accessoryCorner:
            Image(systemName: Self.symbol)
                .widgetAccentable()
                .widgetLabel {
                    Text(content.inlineText)
                }
        default:
            if let place = content.place {
                VStack(alignment: .leading) {
                    Text(place.name)
                        .font(.headline)
                        .widgetAccentable()
                    Text([content.walkingText, content.distanceText].compactMap(\.self).joined(separator: "・"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Label(WatchComplicationContent.emptyMessage, systemImage: Self.symbol)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
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

#Preview(as: .accessoryRectangular) {
    NearbyPlaceWidget()
} timeline: {
    NearbyPlaceEntry.sample
    NearbyPlaceEntry.empty
}

#Preview(as: .accessoryCircular) {
    NearbyPlaceWidget()
} timeline: {
    NearbyPlaceEntry.sample
    NearbyPlaceEntry.empty
}

#Preview(as: .accessoryCorner) {
    NearbyPlaceWidget()
} timeline: {
    NearbyPlaceEntry.sample
}

#Preview(as: .accessoryInline) {
    NearbyPlaceWidget()
} timeline: {
    NearbyPlaceEntry.sample
    NearbyPlaceEntry.empty
}
