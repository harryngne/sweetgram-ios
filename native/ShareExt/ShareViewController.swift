import UIKit
import UniformTypeIdentifiers

/* Bản 11.5 · "Chia sẻ" từ app Ảnh / Safari / app khác vào Sweetgram:
   chép ảnh, video, chữ, đường link vào thư mục chung (App Group) rồi mở Sweetgram — app tự mở màn đăng / gửi với các file đó. */
class ShareViewController: UIViewController {
    let group = (Bundle.main.object(forInfoDictionaryKey: "SweetgramAppGroup") as? String) ?? "group.org.levals.sweetgram"
    let label = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.96)
        label.text = "Đang chuyển sang Sweetgram… 💗"
        label.textAlignment = .center; label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .headline)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([label.centerXAnchor.constraint(equalTo: view.centerXAnchor), label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                                     label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24)])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await collect() }
    }

    func inbox() -> URL? {
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else { return nil }
        let u = root.appendingPathComponent("Inbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    func collect() async {
        guard let dir = inbox() else { finish("Chưa bật App Group — mở Sweetgram một lần rồi thử lại."); return }
        var texts: [String] = []
        var n = 0
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        for item in items {
            if let t = item.attributedContentText?.string, !t.isEmpty { texts.append(t) }
            for p in item.attachments ?? [] {
                for type in [UTType.image, UTType.movie] where p.hasItemConformingToTypeIdentifier(type.identifier) {
                    if let url = await loadFile(p, type) {
                        n += 1
                        let dest = dir.appendingPathComponent(String(format: "%02d-", n) + url.lastPathComponent)
                        try? FileManager.default.removeItem(at: dest)
                        try? FileManager.default.copyItem(at: url, to: dest)
                    }
                    break
                }
                if p.hasItemConformingToTypeIdentifier(UTType.url.identifier), let u = try? await p.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL, !u.isFileURL { texts.append(u.absoluteString) }
                else if p.hasItemConformingToTypeIdentifier(UTType.plainText.identifier), let t = try? await p.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String { texts.append(t) }
            }
        }
        let text = texts.joined(separator: "\n")
        if !text.isEmpty { try? text.write(to: dir.appendingPathComponent("text.txt"), atomically: true, encoding: .utf8) }
        if n == 0 && text.isEmpty { finish("Không có ảnh, video hay chữ để chia sẻ."); return }
        open(URL(string: "sweetgram://shared")!)
        finish(nil)
    }

    func loadFile(_ p: NSItemProvider, _ t: UTType) async -> URL? {
        await withCheckedContinuation { cont in
            _ = p.loadFileRepresentation(forTypeIdentifier: t.identifier) { url, _ in
                guard let url else { cont.resume(returning: nil); return }
                // file tạm chỉ sống trong khối này → chép sang chỗ khác trước khi trả về
                let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.removeItem(at: tmp)
                try? FileManager.default.copyItem(at: url, to: tmp)
                cont.resume(returning: tmp)
            }
        }
    }

    /// mở app chính (extension không có UIApplication.shared → đi tìm qua chuỗi responder)
    func open(_ url: URL) {
        var r: UIResponder? = self
        while let x = r {
            if let app = x as? UIApplication { app.open(url, options: [:], completionHandler: nil); return }
            r = x.next
        }
        _ = extensionContext?.open(url, completionHandler: nil)
    }

    func finish(_ err: String?) {
        DispatchQueue.main.async {
            if let err { self.label.text = err; DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { self.extensionContext?.completeRequest(returningItems: nil) } }
            else { self.label.text = "Đã chuyển sang Sweetgram ✓"; DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.extensionContext?.completeRequest(returningItems: nil) } }
        }
    }
}
