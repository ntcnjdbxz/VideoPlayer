import SwiftUI
import WebKit

struct PlayerFrame: Identifiable {
    let id: Int
    let title: String
    let url: String
}

struct PageMetadata {
    var title = ""
    var url = ""
    var position: Double?
    var duration: Double?
    var season: Int?
    var episode: Int?
    var frames: [PlayerFrame] = []
}

struct WebViewContainer: UIViewRepresentable {
    let url: URL
    let blockAds: Bool
    let seekSeconds: Double?
    let onMetadata: (PageMetadata) -> Void
    let onNavigation: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onMetadata: onMetadata, onNavigation: onNavigation)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContent = WKUserContentController()
        userContent.add(context.coordinator, name: "streamShelf")
        if let jsURL = Bundle.main.url(forResource: "PlaybackBridge", withExtension: "js"),
           let js = try? String(contentsOf: jsURL, encoding: .utf8) {
            userContent.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        config.userContentController = userContent
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        context.coordinator.webView = web
        if blockAds {
            ContentBlocker.compile { list in
                if let list { web.configuration.userContentController.add(list) }
            }
        }
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onMetadata = onMetadata
        context.coordinator.onNavigation = onNavigation
        if let seekSeconds, seekSeconds > 0, context.coordinator.lastSeekSeconds != seekSeconds {
            context.coordinator.lastSeekSeconds = seekSeconds
            let js = """
            (function() {
              const target = \(seekSeconds);
              let tries = 0;
              const timer = setInterval(() => {
                const video = document.querySelector('video');
                if (video && video.readyState >= 1) {
                  try { video.currentTime = target; } catch (_) {}
                  clearInterval(timer);
                }
                if (++tries > 20) clearInterval(timer);
              }, 750);
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
        if webView.url == nil { webView.load(URLRequest(url: url)) }
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
        weak var webView: WKWebView?
        var onMetadata: (PageMetadata) -> Void
        var onNavigation: (URL) -> Void
        var lastSeekSeconds: Double?

        init(onMetadata: @escaping (PageMetadata) -> Void, onNavigation: @escaping (URL) -> Void) {
            self.onMetadata = onMetadata
            self.onNavigation = onNavigation
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let data = message.body as? [String: Any], data["type"] as? String == "metadata" else { return }
            var m = PageMetadata()
            m.title = data["title"] as? String ?? ""
            m.url = data["url"] as? String ?? webView?.url?.absoluteString ?? ""
            m.position = data["position"] as? Double
            m.duration = data["duration"] as? Double
            let pair = MetadataParser.seasonEpisode(data["seasonText"] as? String ?? m.title)
            m.season = pair.0; m.episode = pair.1
            if let frames = data["frames"] as? [[String: Any]] {
                m.frames = frames.compactMap { item in
                    guard let raw = item["src"] as? String, let u = URL(string: raw),
                          ["http","https"].contains(u.scheme?.lowercased() ?? "") else { return nil }
                    return PlayerFrame(id: item["id"] as? Int ?? 0,
                                      title: item["title"] as? String ?? "Player",
                                      url: u.absoluteString)
                }
            }
            onMetadata(m)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let url = webView.url { onNavigation(url) }
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url,
                  ["http","https"].contains(url.scheme?.lowercased() ?? "") else {
                decisionHandler(.cancel); return
            }
            if action.targetFrame == nil { decisionHandler(.cancel); return }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            nil // suppress new-window/pop-up navigation
        }
    }
}
