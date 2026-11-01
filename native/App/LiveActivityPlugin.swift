import Foundation
import Capacitor
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Bật / cập nhật / tắt Live Activity từ trang web; gửi "push token" của activity lên máy chủ để máy chủ tự cập nhật khi app đóng
@objc(LiveActivityPlugin)
public class LiveActivityPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "LiveActivityPlugin"
    public let jsName = "LiveActivity"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "supported", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "start", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "update", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "end", returnType: CAPPluginReturnPromise),
    ]

    @objc func supported(_ call: CAPPluginCall) {
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) { call.resolve(["ok": ActivityAuthorizationInfo().areActivitiesEnabled]); return }
        #endif
        call.resolve(["ok": false])
    }

    #if canImport(ActivityKit)
    @available(iOS 16.2, *)
    private func find(_ kind: String) -> Activity<SweetActivityAttributes>? {
        Activity<SweetActivityAttributes>.activities.first { $0.attributes.kind == kind }
    }
    @available(iOS 16.2, *)
    private func state(_ call: CAPPluginCall) -> SweetActivityAttributes.ContentState {
        SweetActivityAttributes.ContentState(title: call.getString("title") ?? "Sweetgram", subtitle: call.getString("subtitle") ?? "",
                                             emoji: call.getString("emoji") ?? "💗", until: call.getDouble("until"))
    }
    #endif

    @objc func start(_ call: CAPPluginCall) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { call.reject("Cần iOS 16.2"); return }
        let kind = call.getString("kind") ?? "caro"
        let st = state(call)
        if let a = find(kind) {
            Task { await a.update(ActivityContent(state: st, staleDate: nil)); call.resolve(["ok": true, "id": a.id]) }
            return
        }
        do {
            let a = try Activity.request(attributes: SweetActivityAttributes(kind: kind, partner: call.getString("partner") ?? ""),
                                         content: ActivityContent(state: st, staleDate: nil), pushType: .token)
            Task {
                for await data in a.pushTokenUpdates {
                    let token = data.map { String(format: "%02x", $0) }.joined()
                    self.notifyListeners("token", data: ["kind": kind, "token": token])
                }
            }
            call.resolve(["ok": true, "id": a.id])
        } catch { call.reject("Không bật được Live Activity: \(error.localizedDescription)") }
        #else
        call.reject("Không hỗ trợ")
        #endif
    }

    @objc func update(_ call: CAPPluginCall) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *), let a = find(call.getString("kind") ?? "") else { call.resolve(["ok": false]); return }
        let st = state(call)
        Task { await a.update(ActivityContent(state: st, staleDate: nil)); call.resolve(["ok": true]) }
        #else
        call.resolve(["ok": false])
        #endif
    }

    @objc func end(_ call: CAPPluginCall) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { call.resolve(["ok": false]); return }
        let kind = call.getString("kind")
        Task {
            for a in Activity<SweetActivityAttributes>.activities where kind == nil || a.attributes.kind == kind {
                await a.end(nil, dismissalPolicy: .immediate)
            }
            call.resolve(["ok": true])
        }
        #else
        call.resolve(["ok": false])
        #endif
    }
}
