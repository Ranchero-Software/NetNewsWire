//
//  ArticleStatusSyncTimer.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/15/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import Account

@MainActor final class ArticleStatusSyncTimer {
	static let shared = ArticleStatusSyncTimer()

	private static let normalIntervalSeconds: TimeInterval = 120        // 2 minutes
	private static let idleBackoffIntervalSeconds: TimeInterval = 1800  // 30 minutes

	var shuttingDown = false

	private var internalTimer: Timer?
	private var lastTimedRefresh: Date?
	private let launchTime = Date()
	/// True when the most recent timed run was a no-op; the next fire is pushed out.
	private var lastRunWasIdle = false

	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(handleAccountDidQueueArticleStatuses(_:)), name: .AccountDidQueueArticleStatuses, object: nil)
	}

	func fireOldTimer() {
		if let timer = internalTimer {
			if timer.fireDate < Date() {
				timedRefresh(nil)
			}
		}
	}

	func start() {
		shuttingDown = false
	}

	func stop() {
		shuttingDown = true
		invalidate()
	}

	func invalidate() {
		guard let timer = internalTimer else {
			return
		}
		if timer.isValid {
			timer.invalidate()
		}
		internalTimer = nil
	}

	func update() {

		guard !shuttingDown else {
			return
		}

		let interval = lastRunWasIdle ? Self.idleBackoffIntervalSeconds : Self.normalIntervalSeconds
		let lastRefreshDate = lastTimedRefresh ?? launchTime
		var nextRefreshTime = lastRefreshDate.addingTimeInterval(interval)
		if nextRefreshTime < Date() {
			nextRefreshTime = Date().addingTimeInterval(interval)
		}
		if let currentNextFireDate = internalTimer?.fireDate, currentNextFireDate == nextRefreshTime {
			return
		}

		invalidate()
		let timer = Timer(fireAt: nextRefreshTime, interval: 0, target: self, selector: #selector(timedRefresh(_:)), userInfo: nil, repeats: false)
		RunLoop.main.add(timer, forMode: .common)
		internalTimer = timer

	}

	@objc func timedRefresh(_ sender: Timer?) {

		guard !shuttingDown else {
			return
		}

		lastTimedRefresh = Date()
		update()

		Task {
			let didWork = await AccountManager.shared.syncArticleStatusAll()
			self.lastRunWasIdle = !didWork
			// Re-schedule now that we know whether to back off.
			self.update()
		}
	}

	/// User-initiated status changes were queued — exit idle backoff so the
	/// next fire happens on the normal cadence instead of 30 minutes out.
	@objc func handleAccountDidQueueArticleStatuses(_ notification: Notification) {
		guard lastRunWasIdle else {
			return
		}
		lastRunWasIdle = false
		update()
	}
}
