//
//  LaunchSessionStore.swift
//

import Foundation
import Security

/// Launch-flow persistence backed by the Keychain (document URL + native shell flag).
final class LaunchSessionStore {
    static let shared = LaunchSessionStore()

    private static let installMarkerKey = "launch_flow_install_marker"
    private static let legacyNativeShellAccount = "didBootstrapShell"

    private let lastURLKey: String
    private let nativeShellKey: String

    private init() {
        self.lastURLKey = LaunchFlowSecrets.persistedNavigationURLKey
        self.nativeShellKey = LaunchFlowSecrets.nativeShellPresentedKey
    }

    /// UserDefaults is cleared on uninstall; Keychain is not. Reset stale launch-flow state on fresh install.
    func resetIfFreshInstall() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.installMarkerKey) else { return }

        clearAll()
        defaults.set(true, forKey: Self.installMarkerKey)
    }

    func clearAll() {
        savedLastURL = nil
        hasShownNativeShell = false
        KeychainVault.remove(Self.legacyNativeShellAccount)
    }

    /// Persisted document URL after first successful WebView load.
    var savedLastURL: URL? {
        get {
            guard let raw = KeychainVault.string(for: lastURLKey),
                  let url = URL(string: raw) else {
                return nil
            }
            return url
        }
        set {
            if let newValue {
                KeychainVault.set(newValue.absoluteString, for: lastURLKey)
            } else {
                KeychainVault.remove(lastURLKey)
            }
        }
    }

    var hasShownNativeShell: Bool {
        get { KeychainVault.string(for: nativeShellKey) == "1" }
        set { KeychainVault.set(newValue ? "1" : "0", for: nativeShellKey) }
    }
}

/// Minimal generic-password Keychain wrapper scoped to the launch flow.
private enum KeychainVault {
    private static let service = (Bundle.main.bundleIdentifier ?? "app").appending(".launchflow")

    static func string(for account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func set(_ value: String, for account: String) {
        let data = Data(value.utf8)
        let query = baseQuery(account: account)
        let attributes: [String: Any] = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            SecItemAdd(insert as CFDictionary, nil)
        }
    }

    static func remove(_ account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
