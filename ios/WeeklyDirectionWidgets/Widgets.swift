import WidgetKit
import SwiftUI
import AppIntents

@main
struct WeeklyDirectionWidgets: WidgetBundle {
    var body: some Widget {
        WeekWidget()
        DictateWidget()
        TimerLiveActivity()
        if #available(iOS 18.0, *) { DictateControl() }
    }
}

// MARK: timeline

struct WeekEntry: TimelineEntry {
    let date: Date
    let snap: WidgetSnapshot?
}

struct WeekProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeekEntry { WeekEntry(date: Date(), snap: .sample) }
    func getSnapshot(in context: Context, completion: @escaping (WeekEntry) -> Void) {
        completion(WeekEntry(date: Date(), snap: context.isPreview ? .sample : WidgetSnapshot.load() ?? .sample))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WeekEntry>) -> Void) {
        let snap = WidgetSnapshot.load(), now = Date()
        // redraw when an open habit turns into a missed one, and at midnight (the snapshot is for one day)
        var dates = [now] + (snap?.habits.compactMap { $0.missAt }.filter { $0 > now } ?? [])
        dates.append(Calendar.current.startOfDay(for: now).addingTimeInterval(86400 + 1))
        completion(Timeline(entries: dates.sorted().map { WeekEntry(date: $0, snap: snap) }, policy: .atEnd))
    }
}

// MARK: This Week (small, medium, large)

struct WeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WeekWidget", provider: WeekProvider()) { e in
            WeekWidgetView(entry: e)
        }
        .configurationDisplayName("This Week")
        .description("Your focus word, verse and today's habits.")
        // keep our own background wherever iOS would otherwise take it away and show its grey one
        .containerBackgroundRemovable(false)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

struct WeekWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WeekEntry

    var body: some View {
        WeekWidgetBody(snap: entry.snap, date: entry.date,
                       size: family == .systemSmall ? .small : family == .systemMedium ? .medium : family == .accessoryRectangular ? .lock : .large)
            .containerBackground(for: .widget) { WPalette.of(light: entry.snap?.light ?? false).bg }
            .widgetURL(Shared.weekURL)
    }
}

// MARK: Dictate on the Lock Screen (round widget) and as a control

struct DictateWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DictateWidget", provider: WeekProvider()) { _ in
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "mic.fill").font(.system(size: 22, weight: .medium))
            }
            .containerBackground(for: .widget) { Color.clear }
            .widgetURL(Shared.dictateURL)
        }
        .configurationDisplayName("Dictate")
        .description("Straight into recording a thought.")
        .supportedFamilies([.accessoryCircular])
    }
}

@available(iOS 18.0, *)
struct DictateControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "DictateControl") {
            ControlWidgetButton(action: DictateIntent()) { Label("Dictate", systemImage: "mic.fill") }
        }
        .displayName("Dictate")
        .description("Open Weekly Direction and start recording.")
    }
}
