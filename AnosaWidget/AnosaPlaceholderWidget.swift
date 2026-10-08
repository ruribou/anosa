import SwiftUI
import WidgetKit

struct PlaceholderEntry: TimelineEntry {
    let date: Date
}

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry {
        PlaceholderEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) {
        completion(PlaceholderEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [PlaceholderEntry(date: .now)], policy: .never))
    }
}

struct AnosaPlaceholderWidgetView: View {
    let entry: PlaceholderEntry

    var body: some View {
        Text("Anosa")
            .font(.headline)
            .widgetAccentable()
            .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct AnosaPlaceholderWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AnosaPlaceholderWidget", provider: PlaceholderProvider()) { entry in
            AnosaPlaceholderWidgetView(entry: entry)
        }
        .configurationDisplayName("Anosa")
        .description("近くの行きたい場所を表示します。")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline])
    }
}
