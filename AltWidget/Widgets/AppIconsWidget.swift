import SwiftUI
import WidgetKit

private struct AppIconsEntry: TimelineEntry {
    let date: Date
    let apps: [AppSnapshot]
}
private struct AppIconsProvider: TimelineProvider {
    func placeholder(in context: Context) -> AppIconsEntry { AppIconsEntry(date: Date(), apps: []) }
    func getSnapshot(in context: Context, completion: @escaping (AppIconsEntry) -> Void) { completion(makeEntry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<AppIconsEntry>) -> Void) {
        let entry = makeEntry()
        // WidgetDataManager also reloads timelines whenever the app inventory changes.
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
    private func makeEntry() -> AppIconsEntry {
        let snapshot = WidgetDataManager.shared.fetchSnapshot()
        return AppIconsEntry(date: Date(), apps: snapshot.activeApps.map { AppSnapshot(item: $0) })
    }
}
struct AppIconsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LiveContainerAppIcons", provider: AppIconsProvider()) { entry in
            AppIconsWidgetView(apps: entry.apps)
        }
        .configurationDisplayName("LiveContainer Apps")
        .description("An expiry-free, live-updating view of your active apps.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
private struct AppIconsWidgetView: View {
    let apps: [AppSnapshot]
    @Environment(\.widgetFamily) private var family
    private var columns: Int { family == .systemSmall ? 2 : 4 }
    var body: some View {
        let limit = family == .systemSmall ? 4 : family == .systemMedium ? 8 : 16
        Group {
            if apps.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.title2)
                    Text("No active apps")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
                    ForEach(Array(apps.prefix(limit).enumerated()), id: \.offset) { _, app in
                        if let icon = app.icon {
                            Image(uiImage: icon).resizable().aspectRatio(contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        } else {
                            RoundedRectangle(cornerRadius: 13, style: .continuous).fill(.quaternary)
                                .overlay(Image(systemName: "app.fill").foregroundStyle(.secondary))
                        }
                    }
                }
            }
        }
        .padding(4)
        .liveContainerGlassBackground()
    }
}

private extension View {
    @ViewBuilder
    func liveContainerGlassBackground() -> some View {
        if #available(iOSApplicationExtension 26.0, *) {
            self.modifier(LiveContainerGlassBackground())
        } else {
            // widgetBackground keeps the extension compatible with iOS 15/16.
            self.widgetBackground(Rectangle().fill(.ultraThinMaterial))
        }
    }
}

@available(iOSApplicationExtension 26.0, *)
private struct LiveContainerGlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(8)
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
            .containerBackground(for: .widget) { Color.clear }
    }
}
