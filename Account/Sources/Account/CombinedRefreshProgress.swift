//
//  CombinedRefreshProgress.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/7/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

extension Notification.Name {
	public static let combinedRefreshProgressDidChange = Notification.Name("combinedRefreshProgressDidChange")
}

/// Combine the refresh progress of multiple accounts into one place,
/// for use by refresh status view and so on.
public final class CombinedRefreshProgress {

	public private(set) var numberOfTasks = 0
	public private(set) var numberRemaining = 0
	public private(set) var numberCompleted = 0

	public var isComplete: Bool {
		numberRemaining < 1
	}

	init() {

		NotificationCenter.default.addObserver(self, selector: #selector(refreshProgressDidChange(_:)), name: .DownloadProgressDidChange, object: nil)
	}

	func reset() {

		let didMakeChange = numberOfTasks != 0 || numberRemaining != 0 || numberCompleted != 0

		numberOfTasks = 0
		numberRemaining = 0
		numberCompleted = 0

		if didMakeChange {
			postDidChangeNotification()
		}
	}

	@objc func refreshProgressDidChange(_ notification: Notification) {

		var updatedNumberOfTasks = 0
		var updatedNumberRemaining = 0
		var updatedNumberCompleted = 0

		var didMakeChange = false

		let downloadProgresses = AccountManager.shared.activeAccounts.map { $0.refreshProgress }
		for downloadProgress in downloadProgresses {
			updatedNumberOfTasks += downloadProgress.numberOfTasks
			updatedNumberRemaining += downloadProgress.numberRemaining
			updatedNumberCompleted += downloadProgress.numberCompleted
		}

		if updatedNumberOfTasks > numberOfTasks {
			numberOfTasks = updatedNumberOfTasks
			didMakeChange = true
		}

		assert(updatedNumberRemaining <= numberOfTasks)
		updatedNumberRemaining = max(updatedNumberRemaining, numberRemaining)
		updatedNumberRemaining = min(updatedNumberRemaining, numberOfTasks)
		if updatedNumberRemaining != numberRemaining {
			numberRemaining = updatedNumberRemaining
			didMakeChange = true
		}

		assert(updatedNumberCompleted <= numberOfTasks)
		updatedNumberCompleted = max(updatedNumberCompleted, numberCompleted)
		updatedNumberCompleted = min(updatedNumberCompleted, numberOfTasks)
		if updatedNumberCompleted != numberCompleted {
			numberCompleted = updatedNumberCompleted
			didMakeChange = true
		}

		if didMakeChange {
			postDidChangeNotification()
		}
	}
}

private extension CombinedRefreshProgress {

	func postDidChangeNotification() {

		NotificationCenter.default.post(name: .combinedRefreshProgressDidChange, object: self)
	}
}
