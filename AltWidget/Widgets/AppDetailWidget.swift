//
//  AppDetailWidget.swift
//  AltWidgetExtension
//

import SwiftUI
import WidgetKit

/// The LiveContainer status widget intentionally keeps the signing countdown
/// independent of the expiry-free app widgets in this extension.
struct AppDetailWidget: Widget {
    private let kind = "AppDetail"

    var body: some WidgetConfiguration {
        if #available(iOSApplicationExtension 17, *) {
            return AppIntentConfiguration(kind: kind,
                                          intent: SelectAppIntent.self,
                                          provider: SelectAppTimelineProvider()) { entry in
                AppDetailWidgetView(apps: entry.apps, date: entry.date, isPlaceholder: entry.isPlaceholder)
            }
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
            .configurationDisplayName("LiveContainer Status")
            .description("View LiveContainer's remaining signing time. Tap the countdown to refresh your apps.")
            .contentMarginsDisabled()
        } else {
            return IntentConfiguration(kind: kind,
                                       intent: ViewAppIntent.self,
                                       provider: AppsTimelineProvider()) { entry in
                AppDetailWidgetView(apps: entry.apps, date: entry.date, isPlaceholder: entry.isPlaceholder)
            }
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
            .configurationDisplayName("LiveContainer Status")
            .description("View LiveContainer's remaining signing time. Tap the countdown to refresh your apps.")
        }
    }
}

private struct AppDetailWidgetView: View {
    let apps: [AppSnapshot]
    let date: Date
    let isPlaceholder: Bool
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let app = apps.first {
                let daysRemaining = app.expirationDate.numberOfCalendarDays(since: date)
                GeometryReader { geometry in
                    if family == .systemSmall {
                        VStack(alignment: .leading) {
                            statusCopy(daysRemaining: daysRemaining, iconSize: geometry.size.height * 0.36)
                            Spacer(minLength: 0)
                            countdown(for: app, daysRemaining: daysRemaining)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding()
                    } else {
                        HStack(spacing: 20) {
                            statusCopy(daysRemaining: daysRemaining, iconSize: family == .systemLarge ? 72 : 60)
                            Spacer(minLength: 0)
                            countdown(for: app, daysRemaining: daysRemaining)
                                .scaleEffect(family == .systemLarge ? 1.35 : 1.1)
                                .padding(.trailing, family == .systemLarge ? 24 : 10)
                        }
                        .padding()
                    }
                }
                .activatesRefreshAllAppsIntent()
            } else {
                VStack(spacing: 5) {
                    LiveContainerIcon(size: 48)
                    Text("Open LiveContainer")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Text("Launch app to update widget")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .widgetBackground(LiveContainerWidgetBackground())
        .onAppear {
            debugLog("[AppDetailWidgetView] appsCount=\(apps.count), date=\(date)")
        }
    }

    @ViewBuilder
    private func statusCopy(daysRemaining: Int, iconSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            LiveContainerIcon(size: iconSize)
            Text("LIVECONTAINER")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("Expires in")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
            Text(daysRemaining < 0 ? "Expired" : "\(daysRemaining) day\(daysRemaining == 1 ? "" : "s")")
                .font(.system(size: family == .systemLarge ? 30 : 22, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white)
        .widgetAccentableIfAvailable()
    }

    @ViewBuilder
    private func countdown(for app: AppSnapshot, daysRemaining: Int) -> some View {
        if daysRemaining >= 0 {
            Countdown(startDate: app.refreshedDate, endDate: app.expirationDate, currentDate: date)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .invalidatableContentIfAvailable()
        }
    }
}

private struct LiveContainerIcon: View {
    let size: CGFloat

    var body: some View {
        Image("LiveContainer")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

private struct LiveContainerWidgetBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(red: 0.05, green: 0.15, blue: 0.33), Color(red: 0.13, green: 0.43, blue: 0.94)],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }
}

@available(iOS 17, *)
#Preview(as: .systemSmall) {
    AppDetailWidget()
} timeline: {
    let (app, _, _, _, _, _) = AppSnapshot.makePreviewSnapshots()
    AppsEntry<Void>(date: Date(), apps: [app])
}
