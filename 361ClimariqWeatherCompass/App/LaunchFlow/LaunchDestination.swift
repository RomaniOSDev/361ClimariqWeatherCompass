//
//  LaunchDestination.swift
//

import Foundation

enum LaunchDestination: Equatable {
    case native
    case web(URL)
    case staging
}
