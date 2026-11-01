import UIKit
import Capacitor

/// Màn hình chính của app: trang web Sweetgram + đăng ký plugin riêng (widget, Live Activity, hộp nhận chia sẻ)
class MainViewController: CAPBridgeViewController {
    override open func capacitorDidLoad() {
        bridge?.registerPluginInstance(WidgetBridgePlugin())
        bridge?.registerPluginInstance(LiveActivityPlugin())
        bridge?.registerPluginInstance(ScreenGuardPlugin())
    }
}
