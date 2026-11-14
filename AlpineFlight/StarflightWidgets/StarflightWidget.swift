import SwiftUI
import WidgetKit

private enum StarflightDestination {
    static let hangar = URL(string: "starflight://hangar")!
    static let planner = URL(string: "starflight://planner")!
    static let space = URL(string: "starflight://space")!
}

private struct StarflightLaunchEntry: TimelineEntry {
    let date: Date
}

private struct StarflightLaunchProvider: TimelineProvider {
    func placeholder(in context: Context) -> StarflightLaunchEntry {
        StarflightLaunchEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (StarflightLaunchEntry) -> Void) {
        completion(StarflightLaunchEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StarflightLaunchEntry>) -> Void) {
        let now = Date()
        // This is an offline launcher. There are no flight statistics to poll.
        completion(Timeline(entries: [StarflightLaunchEntry(date: now)],
                            policy: .after(now.addingTimeInterval(6 * 60 * 60))))
    }
}

/// A launcher intentionally avoids stale balances or flight status from another process.
@main
struct StarflightQuickLaunchWidget: Widget {
    let kind = "StarflightQuickLaunch"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StarflightLaunchProvider()) { _ in
            StarflightLaunchView()
                .containerBackground(for: .widget) { StarflightWidgetBackdrop() }
                .widgetURL(StarflightDestination.hangar)
        }
        .configurationDisplayName("Starflight")
        .description("Open your hangar, plan a flight, or explore space.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct StarflightLaunchView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .systemMedium {
            medium
        } else {
            small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                StarflightWidgetMark().fill(.white).frame(width: 32, height: 35)
                    .widgetAccentable().accessibilityHidden(true)
                Spacer(minLength: 0)
                Image(systemName: "sparkle").font(.title3).foregroundStyle(.white.opacity(0.65))
                    .accessibilityHidden(true)
            }
            Spacer(minLength: 0)
            Text("STARFLIGHT")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.75).lineLimit(1)
            Text("Your next adventure")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.85)).lineLimit(1).minimumScaleFactor(0.85)
            HStack(spacing: 5) {
                Text("Open hangar")
                Image(systemName: "arrow.up.right")
            }.font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 9).padding(.vertical, 7)
                .background(.white.opacity(0.13), in: Capsule())
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Starflight. Open hangar.")
    }

    private var medium: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                StarflightWidgetMark().fill(.white).frame(width: 39, height: 43)
                    .widgetAccentable().accessibilityHidden(true)
                Spacer(minLength: 0)
                Text("STARFLIGHT")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.75).lineLimit(1)
                Text("Choose your next flight")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85)).lineLimit(2)
            }.frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 7) {
                destination("Hangar", subtitle: "View your ship", icon: "airplane", url: StarflightDestination.hangar)
                destination("Flight planner", subtitle: "Ships, droids & levels", icon: "list.bullet.rectangle", url: StarflightDestination.planner)
                destination("Space free roam", subtitle: "Explore the galaxy", icon: "sparkles", url: StarflightDestination.space)
            }.frame(maxWidth: .infinity)
        }.foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func destination(_ title: String, subtitle: String, icon: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 13, weight: .medium)).frame(width: 18)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 11, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.85)
                    Text(subtitle).font(.system(size: 9)).foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }.padding(.horizontal, 9).padding(.vertical, 6)
                .background(.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
        }
        .accessibilityLabel("Starflight: " + title)
    }
}

/// Original starfighter silhouette drawn as a vector, with no game model loaded.
private struct StarflightWidgetMark: Shape {
    func path(in rect: CGRect) -> Path {
        let points: [CGPoint] = [
            CGPoint(x: 0.5, y: 0), CGPoint(x: 0.6, y: 0.49),
            CGPoint(x: 0.95, y: 0.88), CGPoint(x: 0.65, y: 0.76),
            CGPoint(x: 0.57, y: 1), CGPoint(x: 0.43, y: 1),
            CGPoint(x: 0.35, y: 0.76), CGPoint(x: 0.05, y: 0.88),
            CGPoint(x: 0.4, y: 0.49)
        ]
        var path = Path()
        path.addLines(points.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) })
        path.closeSubpath()
        return path
    }
}

private struct StarflightWidgetBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.035, green: 0.055, blue: 0.13),
                                    Color(red: 0.09, green: 0.12, blue: 0.24)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { context, size in
                for index in 0..<20 {
                    let x = CGFloat((index * 83 + 19) % 997) / 997 * size.width
                    let y = CGFloat((index * 137 + 31) % 991) / 991 * size.height
                    let radius: CGFloat = index.isMultiple(of: 7) ? 1.3 : 0.7
                    let star = Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2))
                    context.fill(star, with: .color(.white.opacity(0.12)))
                }
            }.accessibilityHidden(true)
        }
    }
}

struct StarflightWidgetPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            StarflightLaunchView()
                .containerBackground(for: .widget) { StarflightWidgetBackdrop() }
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small · Open hangar")
            StarflightLaunchView()
                .containerBackground(for: .widget) { StarflightWidgetBackdrop() }
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium · Flight shortcuts")
        }
    }
}
