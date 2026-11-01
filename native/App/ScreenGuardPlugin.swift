import Foundation
import Capacitor
import UIKit

/// Bản 11.10 · Chống quay / chụp màn hình khi xem phim.
///  - captureChanged: báo khi bắt đầu / ngừng quay màn hình hoặc chiếu ra ngoài (AirPlay) → web che đen khung phim (giống Netflix).
///  - screenshot: báo khi vừa chụp màn hình → web nhắc nhở.
///  - setSecure(on): bật "màn hình an toàn" bằng mẹo UITextField bảo mật của iOS → ảnh chụp màn hình ra đen (giống Telegram).
///    (Cần thử trên máy thật; chỉ bật trong lúc xem phim, rời đi là tự tắt khôi phục lại bình thường.)
@objc(ScreenGuardPlugin)
public class ScreenGuardPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "ScreenGuardPlugin"
    public let jsName = "ScreenGuard"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "setSecure", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "isCaptured", returnType: CAPPluginReturnPromise),
    ]

    private var secureField: UITextField?
    private var originalSuperlayer: CALayer?

    public override func load() {
        NotificationCenter.default.addObserver(self, selector: #selector(captureChanged),
            name: UIScreen.capturedDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didShot),
            name: UIApplication.userDidTakeScreenshotNotification, object: nil)
    }

    @objc private func captureChanged() {
        DispatchQueue.main.async { self.notifyListeners("captureChanged", data: ["active": UIScreen.main.isCaptured]) }
    }
    @objc private func didShot() { notifyListeners("screenshot", data: [:]) }

    @objc func isCaptured(_ call: CAPPluginCall) {
        DispatchQueue.main.async { call.resolve(["active": UIScreen.main.isCaptured]) }
    }

    @objc func setSecure(_ call: CAPPluginCall) {
        let on = call.getBool("on") ?? false
        DispatchQueue.main.async {
            guard let window = self.keyWindow() else { call.resolve(["ok": false]); return }
            if on {
                guard self.secureField == nil else { call.resolve(["ok": true]); return }
                let field = UITextField()
                field.isSecureTextEntry = true
                field.isUserInteractionEnabled = false
                field.translatesAutoresizingMaskIntoConstraints = false
                window.addSubview(field)
                NSLayoutConstraint.activate([
                    field.topAnchor.constraint(equalTo: window.topAnchor),
                    field.bottomAnchor.constraint(equalTo: window.bottomAnchor),
                    field.leadingAnchor.constraint(equalTo: window.leadingAnchor),
                    field.trailingAnchor.constraint(equalTo: window.trailingAnchor),
                ])
                // Đưa nội dung cửa sổ vào lớp "canvas bảo mật" của ô mật khẩu → ảnh chụp ra đen
                if let hidden = field.layer.sublayers?.first {
                    self.originalSuperlayer = window.layer.superlayer
                    hidden.addSublayer(window.layer)
                }
                self.secureField = field
                call.resolve(["ok": true])
            } else {
                if let orig = self.originalSuperlayer { orig.addSublayer(window.layer) }  // khôi phục
                self.secureField?.removeFromSuperview()
                self.secureField = nil
                self.originalSuperlayer = nil
                call.resolve(["ok": true])
            }
        }
    }

    private func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }.first { $0.isKeyWindow } ?? UIApplication.shared.windows.first
    }
}
