//
//  LaunchFlowResolver.swift
//

import SwiftUI
import UIKit

/// Orchestrates launch destination: native shell, web document, or staging + probe.
@MainActor
final class LaunchFlowResolver {

    private let sessionStore: LaunchSessionStore
    private let gateEvaluator: CalendarGateEvaluator
    private let urlComposer: RemoteEntryURLComposer
    private let windowPresenter: RootWindowPresenter
    private var activeProbe: RemoteEntryProbe?
    private var stagingProbeCancelled = false

    init(window: UIWindow?) {
        self.sessionStore = LaunchSessionStore.shared
        self.sessionStore.resetIfFreshInstall()
        if sessionStore.savedLastURL == nil {
            sessionStore.hasShownNativeShell = false
        }
        self.gateEvaluator = CalendarGateEvaluator()
        self.urlComposer = RemoteEntryURLComposer()
        self.windowPresenter = RootWindowPresenter(window: window)
    }

    func resolveEntryViewController() -> UIViewController {
        let destination = resolveDestination()
        return viewController(for: destination)
    }

    func cancelPendingOperations() {
        stagingProbeCancelled = true
        activeProbe?.cancel()
        activeProbe = nil
    }

    // MARK: - Destination resolution

    func resolveDestination() -> LaunchDestination {
        guard isRemoteFlowAllowed else {
            return .native
        }

        if sessionStore.hasShownNativeShell {
            return .native
        }

        if sessionStore.savedLastURL != nil {
            // Recompose entry URL on every launch so WKWebView owns cookies/redirects.
            // Persisted value is only a flag that the web path already succeeded once.
            if let entry = urlComposer.composedURL() {
                return .web(entry)
            }
            if let saved = sessionStore.savedLastURL {
                return .web(saved)
            }
        }

        return .staging
    }

    func viewController(for destination: LaunchDestination) -> UIViewController {
        switch destination {
        case .native:
            return makeNativeHost()
        case .web(let url):
            return makeWebHost(url: url)
        case .staging:
            return makeStagingHost()
        }
    }

    private var isRemoteFlowAllowed: Bool {
        gateEvaluator.isGateOpen()
    }

    // MARK: - Hosts

    private func makeNativeHost() -> UIViewController {
        let host = UIHostingController(rootView: ContentView())
        host.modalPresentationStyle = .fullScreen
        return host
    }

    private func makeWebHost(url: URL) -> UIViewController {
        guard isRemoteFlowAllowed else {
            return makeNativeHost()
        }
        let surface = WebDocumentSurfaceView(url: url) { [weak self] in
            self?.pivotToNative()
        }
        let host = UIHostingController(rootView: surface)
        host.modalPresentationStyle = .fullScreen
        return host
    }

    private func makeStagingHost() -> UIViewController {
        guard isRemoteFlowAllowed else {
            return makeNativeHost()
        }

        let state = LaunchStagingState()
        let host = UIHostingController(rootView: DeferredLaunchCanvas(state: state))
        host.modalPresentationStyle = .fullScreen

        stagingProbeCancelled = false
        DispatchQueue.main.async { [weak self] in
            self?.runStagingProbe(state: state)
        }
        return host
    }

    private func runStagingProbe(state: LaunchStagingState) {
        guard !stagingProbeCancelled else { return }
        guard isRemoteFlowAllowed else {
            finishStaging(success: false, webURL: nil)
            return
        }
        guard let entryURL = urlComposer.composedURL() else {
            finishStaging(success: false, webURL: nil)
            return
        }

        let probe = RemoteEntryProbe()
        activeProbe = probe
        // Probe only checks reachability. WebView must start from the entry URL so
        // cookies/redirects happen inside WKWebView (URLSession cookies are not shared).
        probe.probe(entryURL: entryURL, onProgress: { value in
            Task { @MainActor in
                state.progress = value
            }
        }, completion: { [weak self] success, _ in
            Task { @MainActor in
                self?.activeProbe = nil
                guard let self, !self.stagingProbeCancelled else { return }
                self.finishStaging(success: success, webURL: entryURL)
            }
        })
    }

    private func finishStaging(success: Bool, webURL: URL?) {
        guard isRemoteFlowAllowed else {
            pivotToNative()
            return
        }
        guard success, let webURL else {
            pivotToNative()
            return
        }
        pivotToWeb(url: webURL)
    }

    // MARK: - Pivot (after staging)

    func pivotToNative() {
        windowPresenter.slide(to: makeNativeHost())
    }

    func pivotToWeb(url: URL) {
        guard isRemoteFlowAllowed else {
            pivotToNative()
            return
        }
        windowPresenter.slide(to: makeWebHost(url: url))
    }
}
