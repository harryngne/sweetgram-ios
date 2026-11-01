import Foundation
import Capacitor
import WidgetKit

/// Trang web đưa "mã widget" cho app → lưu vào App Group để widget màn hình chính đọc được
@objc(WidgetBridgePlugin)
public class WidgetBridgePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "WidgetBridgePlugin"
    public let jsName = "WidgetBridge"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "setToken", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "reload", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "clear", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "info", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "inbox", returnType: CAPPluginReturnPromise),
    ]

    static var groupId: String {
        (Bundle.main.object(forInfoDictionaryKey: "SweetgramAppGroup") as? String) ?? "group.org.levals.sweetgram"
    }
    private var store: UserDefaults? { UserDefaults(suiteName: Self.groupId) }

    @objc func setToken(_ call: CAPPluginCall) {
        guard let token = call.getString("token"), let base = call.getString("base") else {
            call.reject("Thiếu token/base"); return
        }
        store?.set(token, forKey: "token")
        store?.set(base, forKey: "base")
        WidgetCenter.shared.reloadAllTimelines()
        call.resolve(["ok": true])
    }

    @objc func reload(_ call: CAPPluginCall) {
        WidgetCenter.shared.reloadAllTimelines()
        call.resolve(["ok": true])
    }

    @objc func info(_ call: CAPPluginCall) {
        call.resolve(["aps": (Bundle.main.object(forInfoDictionaryKey: "SweetgramApsEnv") as? String) ?? "production",
                      "group": Self.groupId])
    }

    /// 11.5: ảnh / video / chữ được chia sẻ từ app khác qua Share Extension (lưu tạm trong App Group) → trả cho trang web rồi xoá
    @objc func inbox(_ call: CAPPluginCall) {
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.groupId)?.appendingPathComponent("Inbox", isDirectory: true),
              let names = try? FileManager.default.contentsOfDirectory(atPath: root.path) else { call.resolve(["items": [], "text": ""]); return }
        var items: [[String: Any]] = []
        var text = ""
        for n in names.sorted() {
            let u = root.appendingPathComponent(n)
            if n == "text.txt" { text = (try? String(contentsOf: u, encoding: .utf8)) ?? "" }
            else if let d = try? Data(contentsOf: u), d.count < 60 * 1024 * 1024 {
                let ext = u.pathExtension.lowercased()
                let mime = ["jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png", "heic": "image/heic", "gif": "image/gif", "webp": "image/webp",
                            "mov": "video/quicktime", "mp4": "video/mp4", "m4v": "video/mp4"][ext] ?? "application/octet-stream"
                items.append(["name": n, "mime": mime, "data": d.base64EncodedString()])
            }
            try? FileManager.default.removeItem(at: u)
        }
        call.resolve(["items": items, "text": text])
    }

    @objc func clear(_ call: CAPPluginCall) {
        store?.removeObject(forKey: "token")
        WidgetCenter.shared.reloadAllTimelines()
        call.resolve(["ok": true])
    }
}
