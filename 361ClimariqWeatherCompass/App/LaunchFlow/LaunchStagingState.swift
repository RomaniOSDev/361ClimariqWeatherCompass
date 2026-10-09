//
//  LaunchStagingState.swift
//

import Combine
import Foundation

@MainActor
final class LaunchStagingState: ObservableObject {
    /// Text shown under the staging progress indicator.
    static let defaultStatusMessage = "Preparing your experience..."

    @Published var progress: Double = 0
    @Published var statusMessage: String = LaunchStagingState.defaultStatusMessage
}
