//
//  CombinedRefreshProgress.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/7/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSWeb

/// Combine the refresh progress of multiple accounts into one place,
/// for use by refresh status view and so on.
@MainActor public final class CombinedRefreshProgress: ProgressInfoReporter {
	public static let shared = CombinedRefreshProgress()
	
	public var progressInfo = ProgressInfo() {
		didSet {
			if progressInfo != oldValue {
				postProgressInfoDidChangeNotification()
			}
		}
	}

	public var isComplete: Bool {
		!isStarted || progressInfo.numberRemaining < 1
	}

	private var isStarted = false {
		didSet {
			if isStarted != oldValue {
				progressInfo = ProgressInfo()
			}
		}
	}

	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(progressInfoDidChange(_:)), name: .progressInfoDidChange, object: nil)
	}

	func start() {
		isStarted = true
	}

	func stop() {
		isStarted = false
	}

	@objc func progressInfoDidChange(_ notification: Notification) {
		guard isStarted else {
			return
		}
		guard notification.object is Account else {
			return
		}

		let currentProgressInfo = progressInfo

		let progressInfos = AccountManager.shared.activeAccounts.map { $0.progressInfo }
		let updatedProgressInfo = ProgressInfo.combined(progressInfos)
		var updatedNumberOfTasks = updatedProgressInfo.numberOfTasks
		var updatedNumberCompleted = updatedProgressInfo.numberCompleted
		var updatedNumberRemaining = updatedProgressInfo.numberRemaining

		if updatedNumberOfTasks < currentProgressInfo.numberOfTasks {
			updatedNumberOfTasks = currentProgressInfo.numberOfTasks
		}
		if updatedNumberCompleted < currentProgressInfo.numberCompleted {
			updatedNumberCompleted = currentProgressInfo.numberCompleted
		}
		if updatedNumberCompleted > updatedProgressInfo.numberOfTasks {
			updatedNumberOfTasks = updatedNumberCompleted
		}
		updatedNumberRemaining = updatedNumberOfTasks - updatedNumberCompleted

		progressInfo = ProgressInfo(numberOfTasks: updatedNumberOfTasks,
									numberCompleted: updatedNumberCompleted,
									numberRemaining: updatedNumberRemaining)
	}
}

private extension CombinedRefreshProgress {
	func reset() {
		progressInfo = ProgressInfo()
	}
}
