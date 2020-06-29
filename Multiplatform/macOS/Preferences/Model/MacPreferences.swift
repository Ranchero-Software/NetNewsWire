//
//  MacPreferences.swift
//  macOS
//
//  Created by Stuart Breckenridge on 27/6/20.
//

import SwiftUI

enum FontSize: Int {
	case small = 0
	case medium = 1
	case large = 2
	case veryLarge = 3
}

/// The `MacPreferences` object stores all macOS specific user preferences.
class MacPreferences: ObservableObject {
        
    private struct AppKeys {
        static let refreshInterval = "refreshInterval"
        static let openInBackground = "openInBrowserInBackground"
        static let showUnreadCountInDock = "showUnreadCountInDock"
        static let checkForUpdatesAutomatically = "checkForAppUpdates"
        static let downloadTestBuilds = "downloadTestBuilds"
        static let sendCrashLogs = "sendCrashLogs"
    }
    
    // Refresh Interval
    public let refreshIntervals:[String] = RefreshFrequencies.allCases.map({ $0.description })
    @AppStorage(wrappedValue: 0, AppKeys.refreshInterval) var refreshFrequency {
        didSet {
            objectWillChange.send()
        }
    }
    
    // Open in background
    @AppStorage(wrappedValue: false, AppKeys.openInBackground) var openInBackground {
        didSet {
            objectWillChange.send()
        }
    }
    
    // Unread Count in Dock
    @AppStorage(wrappedValue: true, AppKeys.showUnreadCountInDock) var showUnreadCountInDock {
        didSet {
            objectWillChange.send()
        }
    }
    
    // Check for App Updates
    @AppStorage(wrappedValue: true, AppKeys.checkForUpdatesAutomatically) var checkForUpdatesAutomatically {
        didSet {
            objectWillChange.send()
        }
    }

    // Test builds
    @AppStorage(wrappedValue: false, AppKeys.downloadTestBuilds) var downloadTestBuilds {
        didSet {
            objectWillChange.send()
        }
    }
    
    // Crash Logs
    @AppStorage(wrappedValue: false, AppKeys.sendCrashLogs) var sendCrashLogs {
        didSet {
            objectWillChange.send()
        }
    }
}


enum RefreshFrequencies: CaseIterable, CustomStringConvertible {
    
    case refreshEvery10Mins, refreshEvery20Mins, refreshHourly, refreshEvery2Hours, refreshEvery4Hours, refreshEvery8Hours, none
    
    var description: String {
        switch self {
        case .refreshEvery10Mins:
            return "Every 10 minutes"
        case .refreshEvery20Mins:
            return "Every 20 minutes"
        case .refreshHourly:
            return "Every hour"
        case .refreshEvery2Hours:
            return "Every 2 hours"
        case .refreshEvery4Hours:
            return "Every 4 hours"
        case .refreshEvery8Hours:
            return "Every 8 hours"
        case .none:
            return "Manually"
        }
    }
}
