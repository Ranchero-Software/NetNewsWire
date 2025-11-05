//
//  CoalescingQueue.swift
//  RSCore
//
//  Created by Brent Simmons on 2/17/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// Use when you want to coalesce calls for something like updating visible table cells.
// Calls are uniqued. If you add a call with the same target and selector as a previous call, you’ll just get one call.
// Targets are weakly-held. If a target goes to nil, the call is not performed.
// The perform date is pushed off every time a call is added.
// Calls are FIFO.

struct QueueCall: Equatable {

	weak var target: AnyObject?
	let selector: Selector

	func perform() {

		let _ = target?.perform(selector)
	}

	static func ==(lhs: QueueCall, rhs: QueueCall) -> Bool {

		return lhs.target === rhs.target && lhs.selector == rhs.selector
	}
}

@objc public final class CoalescingQueue: NSObject {

	public static let standard = CoalescingQueue(name: "Standard", interval: 0.05, maxInterval: 0.1)
	public let name: String
	public var isPaused = false
	private let interval: TimeInterval
	private let maxInterval: TimeInterval
	private var lastCallTime = Date.distantFuture
	private var timer: Timer? = nil
	private var calls = [QueueCall]()

	public init(name: String, interval: TimeInterval = 0.05, maxInterval: TimeInterval = 2.0) {
		self.name = name
		self.interval = interval
		self.maxInterval = maxInterval
	}

	public func add(_ target: AnyObject, _ selector: Selector) {
		let queueCall = QueueCall(target: target, selector: selector)
		add(queueCall)
		if Date().timeIntervalSince1970 - lastCallTime.timeIntervalSince1970 > maxInterval {
			timerDidFire(nil)
		}
	}

	public func performCallsImmediately() {
		guard !isPaused else { return }
		let callsToMake = calls // Make a copy in case calls are added to the queue while performing calls.
		resetCalls()
		callsToMake.forEach { $0.perform() }
	}

	@objc func timerDidFire(_ sender: Any?) {
		lastCallTime = Date()
		performCallsImmediately()
	}

}

private extension CoalescingQueue {

	func add(_ call: QueueCall) {
		restartTimer()

		if !calls.contains(call) {
			calls.append(call)
		}
	}

	func resetCalls() {
		calls = [QueueCall]()
	}

	func restartTimer() {
		invalidateTimer()
		timer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(timerDidFire(_:)), userInfo: nil, repeats: false)
	}

	func invalidateTimer() {
		if let timer = timer, timer.isValid {
			timer.invalidate()
		}
		timer = nil
	}
}
