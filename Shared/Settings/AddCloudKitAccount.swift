//
//  AddCloudKitAccount.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/22/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

enum AddCloudKitAccountError: LocalizedError, RecoverableError {
	
	case iCloudDriveMissing

	var errorDescription: String? {
		NSLocalizedString("Can’t Add iCloud Account", comment: "CloudKit account setup failure description — iCloud Drive not enabled.")
	}

	var failureReason: String? {
		#if os(macOS)
		NSLocalizedString("Make sure you have iCloud and iCloud Drive enabled in System Settings.", comment: "CloudKit account setup failure reason — iCloud Drive not enabled.")
		#else
		NSLocalizedString("Make sure you have iCloud and iCloud Drive enabled in Settings.", comment: "CloudKit account setup failure reason — iCloud Drive not enabled.")
		#endif
	}
	
	var recoverySuggestion: String? {
		#if os(macOS)
		NSLocalizedString("Open System Settings to configure iCloud and enable iCloud Drive.", comment: "CloudKit account setup recovery suggestion")
		#else
		NSLocalizedString("Open Settings to configure iCloud and enable iCloud Drive.", comment: "CloudKit account setup recovery suggestion")
		#endif
	}
	
	var recoveryOptions: [String] {
		#if os(macOS)
		[NSLocalizedString("Open System Settings", comment: "Open System Settings button"), NSLocalizedString("Cancel", comment: "Cancel button")]
		#else
		[NSLocalizedString("Open Settings", comment: "Open Settings button"), NSLocalizedString("Cancel", comment: "Cancel button")]
		#endif
	}
	
	func attemptRecovery(optionIndex recoveryOptionIndex: Int) -> Bool {
		guard recoveryOptionIndex == 0 else {
			return false
		}

		AddCloudKitAccountUtilities.openiCloudSettings()
		return true
	}
}

struct AddCloudKitAccountUtilities {

	static var isiCloudDriveEnabled: Bool {
		FileManager.default.ubiquityIdentityToken != nil
	}

	static func openiCloudSettings() {
#if os(macOS)
		if let url = URL(string: "x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane") {
			NSWorkspace.shared.open(url)
		}
#else
		if let url = URL(string: "App-prefs:APPLE_ACCOUNT") {
			UIApplication.shared.open(url)
		}
#endif
	}
}
