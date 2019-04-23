//
//  RefreshTimer.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/23/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation

protocol RefreshTimerDelegate: class {
	func refresh()
}

class RefreshTimer {
	
	var shuttingDown = false
	
	private weak var delegate: RefreshTimerDelegate?
	
	private var internalTimer: Timer?
	private var lastTimedRefresh: Date?
	private let launchTime = Date()
	
	init(delegate: RefreshTimerDelegate) {
		self.delegate = delegate
	}

	func fireOldTimer() {
		if let timer = internalTimer {
			if timer.fireDate < Date() {
				if AppDefaults.refreshInterval != .manually {
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
		
		let refreshInterval = AppDefaults.refreshInterval
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
		print("Next refresh date: \(nextRefreshTime)")
		
	}
	
	@objc func timedRefresh(_ sender: Timer?) {
		guard !shuttingDown else {
			return
		}
		lastTimedRefresh = Date()
		update()
		delegate?.refresh()
	}
	
}
