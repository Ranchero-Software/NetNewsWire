//
//  CoalescingQueue.swift
//  RSCore
//
//  Created by Brent Simmons on 2/17/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Synchronization

// Use when you want to coalesce calls for something like updating visible table cells.
// Calls are uniqued. If you add a call with the same target and selector as a previous call, you’ll just get one call.
// Targets are weakly-held. If a target goes to nil, the call is not performed.
// The perform date is pushed off every time a call is added.
// Calls are FIFO.
// Thread-safe: can be called from any thread, but performs calls on main thread.

struct QueueCall: Equatable {
	weak var target: AnyObject?
	let selector: Selector

	@MainActor func perform() {
		let _ = target?.perform(selector)
	}

	static func ==(lhs: QueueCall, rhs: QueueCall) -> Bool {
		return lhs.target === rhs.target && lhs.selector == rhs.selector
	}
}

nonisolated public final class CoalescingQueue: Sendable {
	public static let standard = CoalescingQueue(name: "Standard", interval: 0.05, maxInterval: 0.1)
	public let name: String
	private let interval: TimeInterval
	private let maxInterval: TimeInterval

	private struct State {
		var isPaused = false
		var lastCallTime = Date.distantFuture
		var timer: Timer? = nil
		var calls = [QueueCall]()
	}

	private let state = Mutex(State())

	public var isPaused: Bool {
		get {
			state.withLock { $0.isPaused }
		}
		set {
			state.withLock { $0.isPaused = newValue }
		}
	}

	public init(name: String, interval: TimeInterval = 0.05, maxInterval: TimeInterval = 2.0) {
		self.name = name
		self.interval = interval
		self.maxInterval = maxInterval
	}

	public func add(_ target: AnyObject, _ selector: Selector) {
		let queueCall = QueueCall(target: target, selector: selector)

		let shouldFireImmediately = state.withLock { state -> Bool in
			_add(queueCall, state: &state)
			return Date().timeIntervalSince1970 - state.lastCallTime.timeIntervalSince1970 > maxInterval
		}

		if shouldFireImmediately {
			timerDidFire()
		}
	}

	public func performCallsImmediately() {
		let callsToMake = state.withLock { state -> [QueueCall]? in
			guard !state.isPaused else { return nil }
			let calls = state.calls
			state.calls = []
			return calls
		}

		guard let callsToMake else { return }

		// Always perform calls on main thread
		if Thread.isMainThread {
			MainActor.assumeIsolated {
				callsToMake.forEach { $0.perform() }
			}
		} else {
			DispatchQueue.main.async {
				callsToMake.forEach { $0.perform() }
			}
		}
	}

	func timerDidFire() {
		state.withLock { $0.lastCallTime = Date() }
		performCallsImmediately()
	}
}

private extension CoalescingQueue {

	private func _add(_ call: QueueCall, state: inout State) {
		_restartTimer(state: &state)

		if !state.calls.contains(call) {
			state.calls.append(call)
		}
	}

	private func _restartTimer(state: inout State) {
		_invalidateTimer(state: &state)

		// Schedule timer on main thread
		DispatchQueue.main.async { [weak self] in
			guard let self else { return }
			self.state.withLock { state in
				state.timer = Timer.scheduledTimer(withTimeInterval: self.interval, repeats: false) { [weak self] _ in
					self?.timerDidFire()
				}
			}
		}
	}

	private func _invalidateTimer(state: inout State) {
		if let timer = state.timer, timer.isValid {
			timer.invalidate()
		}
		state.timer = nil
	}
}
