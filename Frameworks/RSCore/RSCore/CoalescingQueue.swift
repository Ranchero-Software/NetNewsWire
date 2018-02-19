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

	init(target: AnyObject, selector: Selector) {

		self.target = target
		self.selector = selector
	}

	func perform() {

		let _ = target?.perform(selector)
	}

	static func ==(lhs: QueueCall, rhs: QueueCall) -> Bool {

		return lhs.target === rhs.target && lhs.selector == rhs.selector
	}
}

@objc public final class CoalescingQueue: NSObject {

	public static let standard = CoalescingQueue(name: "Standard")
	public let name: String
	private let interval: TimeInterval
	private var timer: Timer? = nil
	private var calls = [QueueCall]()

	public init(name: String, interval: TimeInterval = 0.05) {

		self.name = name
		self.interval = interval
	}

	public func add(_ target: AnyObject, _ selector: Selector) {

		let queueCall = QueueCall(target: target, selector: selector)
		add(queueCall)
	}

	@objc func timerDidFire(_ sender: Any?) {

		let callsToMake = calls // Make a copy in case calls are added to the queue while performing calls.
		resetCalls()
		callsToMake.forEach { $0.perform() }
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
