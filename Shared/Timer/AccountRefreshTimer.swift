//
//  RefreshTimer.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/23/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import Account

class AccountRefreshTimer {
	
	var shuttingDown = false

	private var internalTimer: Timer?
	private var lastTimedRefresh: Date?
	private let launchTime = Date()
	
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
		
		lastTimedRefresh = Date()
		update()
		
		//AccountManager.shared.refreshAll(errorHandler: ErrorHandler.log)
		AccountManager.shared.refreshAll(completion: nil)
	}
	
}
