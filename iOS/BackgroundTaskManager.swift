//
//  BackgroundTaskManager.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 2/1/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation
import UIKit
import BackgroundTasks
import os
import Account

protocol BackgroundTaskManagerDelegate: AnyObject {
	/// Called when application should suspend networking, database, and other processing.
	func backgroundTaskManagerApplicationShouldSuspend(_: BackgroundTaskManager)
}

/// Registers and runs background tasks using the iOS BackgroundTasks API.
final class BackgroundTaskManager {

	static let shared = BackgroundTaskManager()

	weak var delegate: BackgroundTaskManagerDelegate?

	private var backgroundTaskDispatchQueue = DispatchQueue.init(label: "BGTaskScheduler")

	private var waitBackgroundUpdateTask = UIBackgroundTaskIdentifier.invalid
	private var isWaitingForSyncTasks = false

	private var syncBackgroundUpdateTask = UIBackgroundTaskIdentifier.invalid
	private var isSyncArticleStatusRunning = false

	static let refreshTaskIdentifier = "com.ranchero.NetNewsWire.FeedRefresh"

	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "BackgroundTasks")

	/// Register background feed refresh.
	func registerTasks() {
		BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshTaskIdentifier, using: nil) { task in
			self.performBackgroundFeedRefresh(with: task as! BGAppRefreshTask)
		}
	}

	/// Schedules a background app refresh based on `AppDefaults.refreshInterval`.
	func scheduleBackgroundFeedRefresh() {
		let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskIdentifier)
		request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

		// We send this to a dedicated serial queue because as of 11/05/19 on iOS 13.2 the call to the
		// task scheduler can hang indefinitely.
		backgroundTaskDispatchQueue.async {
			do {
				try BGTaskScheduler.shared.submit(request)
			} catch {
				Self.logger.error("Could not schedule app refresh: \(error.localizedDescription)")
			}
		}
	}

	func waitForSyncTasksToFinish() {
		guard !isWaitingForSyncTasks && UIApplication.shared.applicationState == .background else { return }

		isWaitingForSyncTasks = true

		waitBackgroundUpdateTask = UIApplication.shared.beginBackgroundTask {
			self.completeProcessing(true)
			Self.logger.info("Accounts wait for progress terminated for running too long.")
		}

		DispatchQueue.main.async {
			self.waitToComplete { suspend in
				self.completeProcessing(suspend)
			}
		}
	}

	func syncArticleStatus() {
		guard !isSyncArticleStatusRunning else { return }

		isSyncArticleStatusRunning = true

		let completeProcessing = { [unowned self] in
			self.isSyncArticleStatusRunning = false
			UIApplication.shared.endBackgroundTask(self.syncBackgroundUpdateTask)
			self.syncBackgroundUpdateTask = UIBackgroundTaskIdentifier.invalid
		}

		self.syncBackgroundUpdateTask = UIApplication.shared.beginBackgroundTask {
			completeProcessing()
			Self.logger.info("Accounts sync processing terminated for running too long.")
		}

		DispatchQueue.main.async {
			AccountManager.shared.syncArticleStatusAll {
				completeProcessing()
			}
		}
	}
}

private extension BackgroundTaskManager {

	/// Performs background feed refresh.
	/// - Parameter task: `BGAppRefreshTask`
	/// - Warning: As of Xcode 11 beta 2, when triggered from the debugger this doesn't work.
	func performBackgroundFeedRefresh(with task: BGAppRefreshTask) {

		scheduleBackgroundFeedRefresh() // schedule next refresh

		Self.logger.info("Woken to perform account refresh.")

		DispatchQueue.main.async {
			if AccountManager.shared.isSuspended {
				AccountManager.shared.resumeAll()
			}
			AccountManager.shared.refreshAll(errorHandler: ErrorHandler.log) {
				if !AccountManager.shared.isSuspended {
					self.suspendApplication()
					Self.logger.info("Account refresh operation completed.")
					task.setTaskCompleted(success: true)
				}
			}
		}

		// set expiration handler
		task.expirationHandler = { [weak task] in
			Self.logger.info("Accounts refresh processing terminated for running too long.")
			DispatchQueue.main.async {
				self.suspendApplication()
				task?.setTaskCompleted(success: false)
			}
		}
	}

	func waitToComplete(completion: @escaping (Bool) -> Void) {
		guard UIApplication.shared.applicationState == .background else {
			Self.logger.info("App came back to foreground, no longer waiting.")
			completion(false)
			return
		}

		if AccountManager.shared.refreshInProgress || isSyncArticleStatusRunning || WidgetDataEncoder.shared.isRunning {
			Self.logger.info("Waiting for sync to finish…")
			DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
				self.waitToComplete(completion: completion)
			}
		} else {
			Self.logger.info("Refresh progress complete.")
			completion(true)
		}
	}

	func completeProcessing(_ suspend: Bool) {
		if suspend {
			suspendApplication()
		}
		UIApplication.shared.endBackgroundTask(self.waitBackgroundUpdateTask)
		waitBackgroundUpdateTask = UIBackgroundTaskIdentifier.invalid
		isWaitingForSyncTasks = false
	}

	func suspendApplication() {
		assert(delegate != nil)
		assert(Thread.isMainThread)
		delegate?.backgroundTaskManagerApplicationShouldSuspend(self)
	}
}
