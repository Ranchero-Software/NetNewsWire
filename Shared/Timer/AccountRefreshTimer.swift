//
//  RefreshTimer.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/23/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import Account
import ActivityLog

@MainActor final class AccountRefreshTimer {

	var shuttingDown = false
	var isSystemSleeping = false

	private var internalTimer: Timer?
	private var lastTimedRefresh: Date?
	private let launchTime = Date()
	private var suspendedFireDate: Date?

	func fireOldTimer() {
		if let timer = internalTimer {
			if timer.fireDate < Date() {
				if AppDefaults.shared.refreshInterval != .manually {
					timedRefresh(nil)
				}
			}
		}
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

	func suspend() {
		suspendedFireDate = internalTimer?.fireDate
		invalidate()
	}

	func resume() {
		guard !shuttingDown else {
			return
		}
		let dueDate = suspendedFireDate
		suspendedFireDate = nil
		if let dueDate, dueDate < Date() {
			timedRefresh(nil)
		} else {
			update()
		}
	}

	func update() {
		guard !shuttingDown else {
			return
		}

		let refreshInterval = AppDefaults.shared.refreshInterval
		if refreshInterval == .manually {
			invalidate()
			return
		}
		let lastRefreshDate = lastTimedRefresh ?? launchTime
		let secondsToAdd = refreshInterval.inSeconds()
		var nextRefreshTime = lastRefreshDate.addingTimeInterval(secondsToAdd)
		if nextRefreshTime < Date() {
			nextRefreshTime = Date().addingTimeInterval(secondsToAdd)
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

		if isSystemSleeping {
			ActivityLog.shared.logCompletedActivity(owner: .app, kind: .refreshAll, message: "Skipped — computer is asleep")

			lastTimedRefresh = Date()
			update()
			return
		}

		lastTimedRefresh = Date()
		update()

		AccountManager.shared.refreshAllWithoutWaiting()
	}
}
