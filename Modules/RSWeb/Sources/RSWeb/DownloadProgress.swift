//
//  DownloadProgress.swift
//  RSWeb
//
//  Created by Brent Simmons on 9/17/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Synchronization

public extension Notification.Name {

	static let DownloadProgressDidChange = Notification.Name(rawValue: "DownloadProgressDidChange")
}

nonisolated public final class DownloadProgress: Sendable {
	public struct ProgressInfo: Sendable {
		public let numberOfTasks: Int
		public let numberCompleted: Int
		public let numberRemaining: Int
	}

	private struct State {
		var numberOfTasks = 0
		var numberCompleted = 0

		var numberRemaining: Int {
			let n = numberOfTasks - numberCompleted
			assert(n >= 0)
			return n
		}

		init(_ numberOfTasks: Int) {
			self.numberOfTasks = numberOfTasks
		}
	}

	private let state: Mutex<State>

	public init(numberOfTasks: Int) {
		assert(numberOfTasks >= 0)
		self.state = Mutex(State(numberOfTasks))
	}

	public var progressInfo: ProgressInfo {
		var numberOfTasks = 0
		var numberCompleted = 0
		var numberRemaining = 0

		state.withLock { state in
			numberOfTasks = state.numberOfTasks
			numberCompleted = state.numberCompleted
			numberRemaining = state.numberRemaining
		}

		return ProgressInfo(numberOfTasks: numberOfTasks,
							numberCompleted: numberCompleted,
							numberRemaining: numberRemaining)
	}

	public var isComplete: Bool {
		state.withLock { state in
			state.numberRemaining < 1
		}
	}

	public func addTask() {
		addTasks(1)
	}

	public func addTasks(_ n: Int) {
		assert(n > 0)
		state.withLock { state in
			state.numberOfTasks += n
		}
		postDidChangeNotification()
	}

	public func completeTask() {
		completeTasks(1)
	}

	public func completeTasks(_ tasks: Int) {
		state.withLock { state in
			state.numberCompleted += tasks
			assert(state.numberCompleted <= state.numberOfTasks)
		}

		postDidChangeNotification()
	}

	public func reset() {
		state.withLock { state in

			var didChange = false

			if state.numberOfTasks != 0 {
				state.numberOfTasks = 0
				didChange = true
			}
			if state.numberCompleted != 0 {
				state.numberCompleted = 0
				didChange = true
			}

			if didChange {
				postDidChangeNotification()
			}
		}
	}
}

// MARK: - Private

nonisolated private extension DownloadProgress {

	func postDidChangeNotification() {
		DispatchQueue.main.async {
			NotificationCenter.default.post(name: .DownloadProgressDidChange, object: self)
		}
	}
}
