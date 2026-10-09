//
//  RemoteEntryURLComposer.swift
//

import Foundation

struct RemoteEntryURLComposer {

    let template: String
    let trackingParameterName: String

    init(
        template: String = LaunchFlowSecrets.remoteFlowEntryTemplate,
        trackingParameterName: String = LaunchFlowSecrets.trackingSegmentParameterName
    ) {
        self.template = template
        self.trackingParameterName = trackingParameterName
    }

    func composedURL() -> URL? {
        let geo = Locale.current.region?.identifier ?? "XX"
        let appHandle = marketingHandle.replacingOccurrences(of: " ", with: "")
        let subValue = "\(appHandle)_\(geo)"
        let clickId = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()

        var raw = template
        let substitutions: [(String, String)] = [
            ("{subid}", subValue),
            ("{clickid}", clickId),
            ("{subid2}", geo),
            ("%7Bsubid%7D", subValue),
            ("%7Bclickid%7D", clickId),
            ("%7Bsubid2%7D", geo),
            ("%7bsubid%7d", subValue),
            ("%7bclickid%7d", clickId),
            ("%7bsubid2%7d", geo),
        ]
        for (token, value) in substitutions {
            raw = raw.replacingOccurrences(of: token, with: value)
        }

        guard var components = URLComponents(string: raw) else { return nil }
        var items = components.queryItems ?? []
        if !items.contains(where: { $0.name == trackingParameterName }) {
            items.append(URLQueryItem(name: trackingParameterName, value: subValue))
        }
        components.queryItems = items
        return components.url
    }

    private var marketingHandle: String {
        if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "App"
    }
}
