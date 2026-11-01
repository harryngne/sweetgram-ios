import WidgetKit
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif

/* Bản 11.5 · Widget màn hình khoá (tròn / chữ nhật / một dòng): số ngày bên nhau, giờ bên kia, ngày gặp tới, lượt caro */

struct LockEntry: TimelineEntry {
    let date: Date
    let name: String
    let days: Int
    let tz: TimeZone?
    let meet: Date?
    let caroTurn: Bool
    let ok: Bool
}

struct LockProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockEntry { LockEntry(date: Date(), name: "Người ấy", days: 365, tz: TimeZone(identifier: "America/New_York"), meet: Date().addingTimeInterval(12 * 86400), caroTurn: false, ok: true) }
    func getSnapshot(in context: Context, completion: @escaping (LockEntry) -> Void) {
        if context.isPreview { completion(placeholder(in: context)); return }
        Task { completion(await load()) }
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LockEntry>) -> Void) {
        Task {
            let e = await load()
            // giờ bên kia đổi theo phút → tạo sẵn 30 mục, mỗi mục cách 1 phút (rồi tải lại)
            var list: [LockEntry] = []
            for k in 0..<30 { list.append(LockEntry(date: Date().addingTimeInterval(Double(k) * 60), name: e.name, days: e.days, tz: e.tz, meet: e.meet, caroTurn: e.caroTurn, ok: e.ok)) }
            completion(Timeline(entries: list, policy: .atEnd))
        }
    }
    func load() async -> LockEntry {
        let d = UserDefaults(suiteName: appGroup)
        guard let token = d?.string(forKey: "token"), let base = d?.string(forKey: "base"),
              let q = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: base + "api.php?action=widget&t=" + q) else {
            return LockEntry(date: Date(), name: "", days: 0, tz: nil, meet: nil, caroTurn: false, ok: false)
        }
        if let (data, _) = try? await URLSession.shared.data(from: url), let f = try? JSONDecoder().decode(WidgetFeed.self, from: data) {
            let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
            d?.set(data, forKey: "lastFeed")
            return LockEntry(date: Date(), name: f.name, days: f.days, tz: f.tz.flatMap { TimeZone(identifier: $0) }, meet: f.meet.flatMap { df.date(from: $0) }, caroTurn: f.caroTurn ?? false, ok: true)
        }
        if let data = d?.data(forKey: "lastFeed"), let f = try? JSONDecoder().decode(WidgetFeed.self, from: data) {
            return LockEntry(date: Date(), name: f.name, days: f.days, tz: f.tz.flatMap { TimeZone(identifier: $0) }, meet: nil, caroTurn: false, ok: true)
        }
        return LockEntry(date: Date(), name: "", days: 0, tz: nil, meet: nil, caroTurn: false, ok: false)
    }
}

struct LockView: View {
    var e: LockEntry
    @Environment(\.widgetFamily) var family
    var theirTime: String? {
        guard let tz = e.tz else { return nil }
        let f = DateFormatter(); f.timeZone = tz; f.dateFormat = "HH:mm"; return f.string(from: e.date)
    }
    var meetDays: Int? { e.meet.map { max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: e.date), to: $0).day ?? 0) } }
    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text(e.caroTurn ? "⭕" : "❤️").font(.system(size: 14))
                    Text(meetDays.map { "\($0)" } ?? "\(e.days)").font(.system(size: 17, weight: .bold)).minimumScaleFactor(0.6)
                    Text(meetDays != nil ? "ngày nữa" : "ngày").font(.system(size: 8))
                }
            }
        case .accessoryInline:
            if let m = meetDays { Text("❤️ \(e.days) ngày · còn \(m) ngày gặp") } else { Text("❤️ \(e.days) ngày bên \(e.name)") }
        default:
            VStack(alignment: .leading, spacing: 1) {
                Text("❤️ \(e.days) ngày · \(e.name)").font(.headline).lineLimit(1)
                if let t = theirTime { Text("🕐 Bên đó \(t)").font(.caption).lineLimit(1) }
                if e.caroTurn { Text("⭕ Tới lượt bạn đi caro").font(.caption).bold().lineLimit(1) }
                else if let m = meetDays { Text("✈️ Còn \(m) ngày gặp nhau").font(.caption).lineLimit(1) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SweetLockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SweetLock", provider: LockProvider()) { e in
            LockView(e: e).widgetURL(URL(string: "sweetgram://open")).containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Sweetgram · màn hình khoá")
        .description("Số ngày bên nhau, giờ bên kia, ngày gặp tới, lượt caro.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

/* ---------- Live Activity: màn hình khoá + Dynamic Island ---------- */
struct SweetLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SweetActivityAttributes.self) { ctx in
            HStack(spacing: 12) {
                Text(ctx.state.emoji).font(.system(size: 34))
                VStack(alignment: .leading, spacing: 2) {
                    Text(ctx.state.title).font(.headline).lineLimit(1)
                    Text(ctx.state.subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if let u = ctx.state.until, u > Date().timeIntervalSince1970 {
                    Text(timerInterval: Date()...Date(timeIntervalSince1970: u), countsDown: true).font(.title3.monospacedDigit()).frame(maxWidth: 90).multilineTextAlignment(.trailing)
                }
            }
            .padding(16)
            .activityBackgroundTint(Color(red: 0.12, green: 0.08, blue: 0.2))
            .activitySystemActionForegroundColor(.white)
            .widgetURL(URL(string: "sweetgram://open?kind=\(ctx.attributes.kind)"))
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Text(ctx.state.emoji).font(.largeTitle) }
                DynamicIslandExpandedRegion(.center) { VStack(spacing: 2) { Text(ctx.state.title).font(.headline).lineLimit(1); Text(ctx.state.subtitle).font(.caption).lineLimit(1) } }
                DynamicIslandExpandedRegion(.trailing) {
                    if let u = ctx.state.until, u > Date().timeIntervalSince1970 { Text(timerInterval: Date()...Date(timeIntervalSince1970: u), countsDown: true).font(.caption.monospacedDigit()).frame(maxWidth: 60) }
                }
            } compactLeading: {
                Text(ctx.state.emoji)
            } compactTrailing: {
                if let u = ctx.state.until, u > Date().timeIntervalSince1970 {
                    Text(timerInterval: Date()...Date(timeIntervalSince1970: u), countsDown: true).monospacedDigit().frame(maxWidth: 44)
                } else {
                    Text(ctx.attributes.kind == "caro" ? "caro" : "💗").font(.caption2)
                }
            } minimal: {
                Text(ctx.state.emoji)
            }
            .widgetURL(URL(string: "sweetgram://open?kind=\(ctx.attributes.kind)"))
        }
    }
}
