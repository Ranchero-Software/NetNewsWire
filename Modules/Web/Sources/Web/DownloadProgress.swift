//
//  DownloadProgress.swift
//  RSWeb
//
//  Created by Brent Simmons on 9/17/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os

public extension Notification.Name {
	
	static let DownloadProgressDidChange = Notification.Name(rawValue: "DownloadProgressDidChange")
}

public final class DownloadProgress: Sendable {

	public struct TaskCount: Sendable {

		public var numberOfTasks = 0
		public var numberCompleted = 0

		public var numberRemaining: Int {
			let n = numberOfTasks - numberCompleted
			assert(n >= 0)
			return n
		}
	}

	private let taskCount: OSAllocatedUnfairLock<TaskCount>

	public var taskCounts: TaskCount {
		taskCount.withLock { $0 }
	}

	public var isComplete: Bool {
		taskCount.withLock { $0.numberRemaining < 1 }
	}

	public init(numberOfTasks: Int) {

		assert(numberOfTasks >= 0)
		self.taskCount = OSAllocatedUnfairLock(initialState: TaskCount(numberOfTasks: numberOfTasks))
	}

	public func addTask() {

		addTasks(1)
	}

	public func addTasks(_ n: Int) {

		assert(n > 0)

		taskCount.withLock {
			$0.numberOfTasks = $0.numberOfTasks + n
		}
		postDidChangeNotification()
	}

	public func completeTask() {

		completeTasks(1)
	}

	public func completeTasks(_ tasks: Int) {

		taskCount.withLock { taskCount in
			taskCount.numberCompleted = taskCount.numberCompleted + tasks
			assert(taskCount.numberCompleted <= taskCount.numberOfTasks)
		}

		postDidChangeNotification()
	}

	public func clear() {

		taskCount.withLock { taskCount in

			var didChange = false

			if taskCount.numberOfTasks != 0 {
				taskCount.numberOfTasks = 0
				didChange = true
			}
			if taskCount.numberCompleted != 0 {
				taskCount.numberCompleted = 0
				didChange = true
			}

			if didChange {
				postDidChangeNotification()
			}
		}
	}
}

// MARK: - Private

private extension DownloadProgress {

	func postDidChangeNotification() {
		Task { @MainActor in
			NotificationCenter.default.post(name: .DownloadProgressDidChange, object: self)
		}
	}
}
