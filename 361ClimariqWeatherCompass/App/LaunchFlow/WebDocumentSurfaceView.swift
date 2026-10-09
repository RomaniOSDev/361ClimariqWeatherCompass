//
//  WebDocumentSurfaceView.swift
//

import SwiftUI
import WebKit

struct WebDocumentSurfaceView: View {
    let url: URL
    var onFailure: () -> Void

    @State private var webView: WKWebView?
    @State private var canGoBack = false
    @State private var isLoading = true

    private let chromeTint = Color(red: 0.20, green: 0.16, blue: 0.42)

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.96, blue: 0.99).ignoresSafeArea()

            VStack(spacing: 0) {
                WebDocumentHostRepresentable(
                    url: url,
                    webView: $webView,
                    canGoBack: $canGoBack,
                    isLoading: $isLoading,
                    onFailure: onFailure
                )

                Divider()
                    .overlay(Color.black.opacity(0.08))

                HStack(spacing: 36) {
                    Button {
                        webView?.goBack()
                    } label: {
                        Image(systemName: "arrow.backward")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(canGoBack ? chromeTint : Color.gray.opacity(0.4))
                            .frame(width: 44, height: 44)
                    }
                    .disabled(!canGoBack)

                    Button {
                        webView?.reload()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(chromeTint)
                            .frame(width: 44, height: 44)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(.ultraThinMaterial)
            }

            if isLoading {
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: chromeTint))
                        .scaleEffect(1.8)
                }
                .allowsHitTesting(false)
            }
        }
        .persistentSystemOverlays(.hidden)
    }
}

// MARK: - UIViewRepresentable

struct WebDocumentHostRepresentable: UIViewRepresentable {
    let url: URL
    @Binding var webView: WKWebView?
    @Binding var canGoBack: Bool
    @Binding var isLoading: Bool
    var onFailure: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        let stub = """
        (function () {
          if (typeof Notification === 'undefined') {
            window.Notification = function () {};
            window.Notification.permission = 'default';
            window.Notification.requestPermission = function () {
              return Promise.resolve('default');
            };
          } else if (typeof Notification.permission === 'undefined') {
            Notification.permission = 'default';
          }
          if (!navigator.permissions || typeof navigator.permissions.query !== 'function') {
            navigator.permissions = {
              query: function () {
                return Promise.resolve({ state: 'prompt', onchange: null });
              }
            };
          }

          // Keep popup-based tracker redirects inside the current WKWebView.
          // Returning the current window is important: some scripts stop when
          // window.open() returns null.
          var nativeOpen = window.open;
          window.open = function (url, target, features) {
            if (typeof url === 'string' && url.length > 0) {
              window.location.assign(url);
            }
            return window;
          };
        })();
        """
        let script = WKUserScript(
            source: stub,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        configuration.userContentController.addUserScript(script)

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.backgroundColor = .white
        view.isOpaque = true
        view.allowsBackForwardNavigationGestures = true
        // Prefer Safari-like UA — many TDS/offer pages blank out default WKWebView UA.
        view.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        context.coordinator.attach(webView: view)
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
        // Do not write @Binding here — triggers "Modifying state during view update".
        if webView !== uiView {
            DispatchQueue.main.async {
                webView = uiView
            }
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebDocumentHostRepresentable
        private weak var attachedWebView: WKWebView?
        private var failureCalled = false
        /// After first paint, ignore further redirects so the spinner never sticks.
        private var hasRevealedContent = false
        private var revealTimeoutWork: DispatchWorkItem?

        init(parent: WebDocumentHostRepresentable) {
            self.parent = parent
        }

        func attach(webView: WKWebView) {
            attachedWebView = webView
            scheduleRevealTimeout()
        }

        private func scheduleRevealTimeout() {
            revealTimeoutWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.revealContent()
            }
            revealTimeoutWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: work)
        }

        private func revealContent() {
            revealTimeoutWork?.cancel()
            revealTimeoutWork = nil
            hasRevealedContent = true
            publishLoading(false)
        }

        private func publishLoading(_ loading: Bool) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.parent.isLoading != loading {
                    self.parent.isLoading = loading
                }
            }
        }

        private func publishCanGoBack(_ value: Bool) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.parent.canGoBack != value {
                    self.parent.canGoBack = value
                }
            }
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if let httpResponse = navigationResponse.response as? HTTPURLResponse {
                if LaunchSessionStore.shared.savedLastURL == nil && !failureCalled {
                    if (400...599).contains(httpResponse.statusCode) {
                        failureCalled = true
                        LaunchSessionStore.shared.hasShownNativeShell = true
                        decisionHandler(.cancel)
                        DispatchQueue.main.async { self.parent.onFailure() }
                        return
                    }
                }
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url,
               ["mailto", "tel", "sms"].contains(url.scheme?.lowercased()) {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            // Only show the initial overlay — TDS redirect chains would otherwise keep it forever.
            if !hasRevealedContent {
                publishLoading(true)
            }
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            revealContent()
            publishCanGoBack(webView.canGoBack)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            revealContent()
            publishCanGoBack(webView.canGoBack)
            // Persist the entry URL (not the redirected offer URL) so relaunch
            // can replay cookies/redirects inside WKWebView.
            if LaunchSessionStore.shared.savedLastURL == nil {
                LaunchSessionStore.shared.savedLastURL = parent.url
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            // Redirect cancellation is normal; do not treat as load failure.
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return
            }
            revealContent()
            triggerFailureIfNeeded()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return
            }
            revealContent()
            if LaunchSessionStore.shared.savedLastURL == nil {
                triggerFailureIfNeeded()
            }
        }

        private func triggerFailureIfNeeded() {
            guard LaunchSessionStore.shared.savedLastURL == nil, !failureCalled else { return }
            failureCalled = true
            LaunchSessionStore.shared.hasShownNativeShell = true
            DispatchQueue.main.async { self.parent.onFailure() }
        }
    }
}
