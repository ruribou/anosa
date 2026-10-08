import SwiftUI
import WidgetKit

struct WatchPlaceholderEntry: TimelineEntry {
    let date: Date
}

struct WatchPlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchPlaceholderEntry {
        WatchPlaceholderEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchPlaceholderEntry) -> Void) {
        completion(WatchPlaceholderEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchPlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [WatchPlaceholderEntry(date: .now)], policy: .never))
    }
}

struct AnosaWatchPlaceholderWidgetView: View {
    let entry: WatchPlaceholderEntry

    var body: some View {
        Image(systemName: "mappin.and.ellipse")
            .widgetAccentable()
            .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct AnosaWatchPlaceholderWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AnosaWatchPlaceholderWidget", provider: WatchPlaceholderProvider()) { entry in
            AnosaWatchPlaceholderWidgetView(entry: entry)
        }
        .configurationDisplayName("Anosa")
        .description("近くの行きたい場所を表示します。")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
    }
}
