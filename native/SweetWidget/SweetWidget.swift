import WidgetKit
import SwiftUI

/* (cần iOS 17 trở lên) Widget màn hình chính: ảnh mới nhất của người kia (kiểu Locket) + số ngày bên nhau.
   Tự tải lại mỗi 15 phút, và ngay khi app báo có ảnh mới. */

let appGroup = (Bundle.main.object(forInfoDictionaryKey: "SweetgramAppGroup") as? String) ?? "group.org.levals.sweetgram"

struct WidgetFeed: Decodable {
    struct Item: Decodable { let id: Int; let byName: String; let caption: String; let at: String; let img: String }
    let name: String
    let days: Int
    let item: Item?
    let tz: String?
    let meet: String?
    let caroTurn: Bool?
}

struct SweetEntry: TimelineEntry {
    let date: Date
    let image: UIImage?
    let name: String
    let byName: String
    let caption: String
    let days: Int
    let postedAt: Date?
    let state: State
    enum State { case ok, needLogin, offline }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SweetEntry {
        SweetEntry(date: Date(), image: nil, name: "Người ấy", byName: "Người ấy", caption: "", days: 365, postedAt: Date(), state: .ok)
    }
    func getSnapshot(in context: Context, completion: @escaping (SweetEntry) -> Void) {
        if context.isPreview { completion(placeholder(in: context)); return }
        Task { completion(await load(maxPx: context.displaySize.width)) }
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SweetEntry>) -> Void) {
        Task {
            let e = await load(maxPx: context.displaySize.width)
            let next = Calendar.current.date(byAdding: .minute, value: e.state == .ok ? 15 : 30, to: Date())!
            completion(Timeline(entries: [e], policy: .after(next)))
        }
    }

    func load(maxPx: CGFloat) async -> SweetEntry {
        let d = UserDefaults(suiteName: appGroup)
        guard let token = d?.string(forKey: "token"), let base = d?.string(forKey: "base"),
              let q = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: base + "api.php?action=widget&t=" + q) else {
            return SweetEntry(date: Date(), image: nil, name: "", byName: "", caption: "", days: 0, postedAt: nil, state: .needLogin)
        }
        do {
            var req = URLRequest(url: url); req.timeoutInterval = 15
            let (data, res) = try await URLSession.shared.data(for: req)
            if (res as? HTTPURLResponse)?.statusCode == 401 {
                return SweetEntry(date: Date(), image: nil, name: "", byName: "", caption: "", days: 0, postedAt: nil, state: .needLogin)
            }
            let feed = try JSONDecoder().decode(WidgetFeed.self, from: data)
            var img: UIImage? = nil
            if let it = feed.item, let iu = URL(string: base + it.img) {
                if let (bytes, _) = try? await URLSession.shared.data(from: iu), let raw = UIImage(data: bytes) {
                    img = downscale(raw, to: max(maxPx, 200) * 2)   // widget bị giới hạn bộ nhớ → thu nhỏ
                    d?.set(bytes, forKey: "lastImage")
                }
            }
            let fmt = ISO8601DateFormatter()
            return SweetEntry(date: Date(), image: img, name: feed.name, byName: feed.item?.byName ?? feed.name, caption: feed.item?.caption ?? "",
                              days: feed.days, postedAt: feed.item.flatMap { fmt.date(from: $0.at) }, state: .ok)
        } catch {
            // mất mạng: dùng ảnh lần trước
            let last = d?.data(forKey: "lastImage").flatMap { UIImage(data: $0) }
            return SweetEntry(date: Date(), image: last.map { downscale($0, to: max(maxPx, 200) * 2) }, name: "", byName: "", caption: "", days: 0, postedAt: nil, state: .offline)
        }
    }

    func downscale(_ im: UIImage, to px: CGFloat) -> UIImage {
        let k = min(1, px / max(im.size.width, im.size.height))
        if k >= 1 { return im }
        let size = CGSize(width: im.size.width * k, height: im.size.height * k)
        return UIGraphicsImageRenderer(size: size).image { _ in im.draw(in: CGRect(origin: .zero, size: size)) }
    }
}

struct SweetWidgetView: View {
    var entry: SweetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let im = entry.image {
                Image(uiImage: im).resizable().scaledToFill()
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
            } else {
                LinearGradient(colors: [Color(red: 1, green: 0.18, blue: 0.39), Color(red: 0.63, green: 0.2, blue: 1)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            VStack(alignment: .leading, spacing: 2) {
                if entry.state == .needLogin {
                    Text("💌").font(.title)
                    Text("Mở Sweetgram để bật widget").font(.caption).bold().foregroundColor(.white)
                } else {
                    if family != .systemSmall, !entry.caption.isEmpty {
                        Text(entry.caption).font(.caption).foregroundColor(.white).lineLimit(2)
                    }
                    HStack(spacing: 4) {
                        Text(entry.byName).font(.caption2).bold().foregroundColor(.white).lineLimit(1)
                        if let at = entry.postedAt {
                            Text("· " + at.formatted(.relative(presentation: .numeric, unitsStyle: .narrow))).font(.caption2).foregroundColor(.white.opacity(0.85)).lineLimit(1)
                        }
                    }
                    if entry.days > 0 {
                        Text("❤️ \(entry.days) ngày").font(.caption2).bold().foregroundColor(.white.opacity(0.95))
                    }
                }
            }
            .padding(10)
            .shadow(color: .black.opacity(0.4), radius: 2)
        }
        .widgetURL(URL(string: "sweetgram://open"))
        .containerBackground(for: .widget) { Color.black }
    }
}

struct SweetWidget: Widget {
    let kind = "SweetWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in SweetWidgetView(entry: entry) }
            .configurationDisplayName("Sweetgram")
            .description("Ảnh mới nhất của người ấy, ngay trên màn hình chính.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
            .contentMarginsDisabled()
    }
}

@main
struct SweetWidgets: WidgetBundle {
    var body: some Widget {
        SweetWidget()
        SweetLockWidget()
        SweetLiveActivityWidget()
    }
}
