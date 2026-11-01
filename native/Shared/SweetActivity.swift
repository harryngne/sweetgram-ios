import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// Live Activity của Sweetgram (dùng chung cho app và widget): lượt caro, xem chung, đếm ngược ngày gặp, nghe nhạc chung
public struct SweetActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var title: String
        public var subtitle: String
        public var emoji: String
        /// mốc thời gian (giây UNIX) để đếm ngược — ví dụ hạn chót nước caro, ngày gặp nhau
        public var until: Double?
        public init(title: String, subtitle: String, emoji: String, until: Double? = nil) {
            self.title = title; self.subtitle = subtitle; self.emoji = emoji; self.until = until
        }
    }
    /// caro | watch | meet | music
    public var kind: String
    public var partner: String
    public init(kind: String, partner: String) { self.kind = kind; self.partner = partner }
}
#endif
