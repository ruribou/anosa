import AnosaKit
import SwiftUI
import WidgetKit

struct NearestPlaceEntry: TimelineEntry {
    let date: Date
    let display: NearestPlaceDisplay
}

struct NearestPlaceProvider: TimelineProvider {
    /// ギャラリー・プレースホルダー用のダミー。実在の場所・座標ではない。
    static let sampleDisplay = NearestPlaceDisplay(
        snapshot: LocationSnapshot(
            location: Coordinate(latitude: 0, longitude: 0),
            capturedAt: .now,
            places: [
                NearbyPlace(
                    id: UUID(),
                    name: "行きたかったカフェ",
                    coordinate: Coordinate(latitude: 0, longitude: 0),
                    distanceMeters: 350,
                    walkingMinutes: 5
                )
            ]
        )
    )

    func placeholder(in context: Context) -> NearestPlaceEntry {
        NearestPlaceEntry(date: .now, display: Self.sampleDisplay)
    }

    func getSnapshot(in context: Context, completion: @escaping (NearestPlaceEntry) -> Void) {
        let display = context.isPreview ? Self.sampleDisplay : currentDisplay()
        completion(NearestPlaceEntry(date: .now, display: display))
    }

    /// 位置が変わったときにアプリが reloadAllTimelines を呼ぶため、ウィジェット側からは更新を求めない。
    func getTimeline(in context: Context, completion: @escaping (Timeline<NearestPlaceEntry>) -> Void) {
        let entry = NearestPlaceEntry(date: .now, display: currentDisplay())
        completion(Timeline(entries: [entry], policy: .never))
    }

    private func currentDisplay() -> NearestPlaceDisplay {
        NearestPlaceDisplay(snapshot: LocationSnapshotStore.shared().load())
    }
}

struct NearestPlaceWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NearestPlaceEntry

    var body: some View {
        content
            .containerBackground(for: .widget) {
                background
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Text(entry.display.inlineText)
        case .accessoryCircular:
            CircularView(display: entry.display)
        case .accessoryRectangular:
            RectangularView(display: entry.display)
        default:
            SmallView(display: entry.display)
        }
    }

    @ViewBuilder
    private var background: some View {
        switch family {
        case .accessoryCircular, .accessoryRectangular:
            AccessoryWidgetBackground()
        case .accessoryInline:
            EmptyView()
        default:
            Rectangle().fill(.fill.tertiary)
        }
    }
}

private struct SmallView: View {
    let display: NearestPlaceDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(WidgetCopy.nearestHeading)
                .font(.caption)
                .foregroundStyle(.secondary)
            switch display {
            case .nearest(let summary):
                Text(summary.name)
                    .font(.headline)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .widgetAccentable()
                Spacer(minLength: 0)
                Text(summary.distanceText)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(summary.walkingText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            case .locationUnavailable, .noNearbyPlaces:
                Spacer(minLength: 0)
                Text(display.message ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct RectangularView: View {
    let display: NearestPlaceDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(WidgetCopy.nearestHeading)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            switch display {
            case .nearest(let summary):
                Text(summary.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .widgetAccentable()
                Text("\(summary.distanceText)・\(summary.walkingText)")
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            case .locationUnavailable, .noNearbyPlaces:
                Text(display.message ?? "")
                    .font(.caption)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CircularView: View {
    let display: NearestPlaceDisplay

    var body: some View {
        switch display {
        case .nearest(let summary):
            VStack(spacing: 0) {
                Image(systemName: "mappin")
                    .font(.caption2)
                    .widgetAccentable()
                Text(summary.distanceText)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(4)
        case .locationUnavailable, .noNearbyPlaces:
            Image(systemName: "mappin.slash")
                .font(.title3)
                .foregroundStyle(.secondary)
                .accessibilityLabel(display.message ?? "")
        }
    }
}

struct NearestPlaceWidget: Widget {
    static let kind = "NearestPlaceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: NearestPlaceProvider()) { entry in
            NearestPlaceWidgetView(entry: entry)
        }
        .configurationDisplayName("いちばん近い行きたい場所")
        .description("今いる場所からいちばん近い、行きたい場所と距離を出します。")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}
