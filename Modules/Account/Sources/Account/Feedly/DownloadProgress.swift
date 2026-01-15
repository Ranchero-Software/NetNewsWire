//
//  DownloadProgress.swift
//  RSWeb
//
//  Created by Brent Simmons on 9/17/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore

// Legacy — used only by Feedly.
// TODO: use new progress stuff.
// Main thread only.

public extension Notification.Name {
	static let DownloadProgressDidChange = Notification.Name(rawValue: "DownloadProgressDidChange")
}

@MainActor final class DownloadProgress {

	var numberOfTasks = 0 {
		didSet {
			if numberOfTasks == 0 && numberRemaining != 0 {
				numberRemaining = 0
			}
			if numberOfTasks != oldValue {
				postDidChangeNotification()
			}
		}
	}

	var numberRemaining = 0 {
		didSet {
			if numberRemaining != oldValue {
				postDidChangeNotification()
			}
		}
	}

	var numberCompleted: Int {
		var n = numberOfTasks - numberRemaining
		if n < 0 {
			n = 0
		}
		if n > numberOfTasks {
			n = numberOfTasks
		}
		return n
	}
	
	var isComplete: Bool {
		assert(Thread.isMainThread)
		return numberRemaining < 1
	}
	
	init(numberOfTasks: Int) {
		assert(Thread.isMainThread)
		self.numberOfTasks = numberOfTasks
	}
	
	func addToNumberOfTasks(_ n: Int) {
		assert(Thread.isMainThread)
		numberOfTasks = numberOfTasks + n
	}
	
	func addToNumberOfTasksAndRemaining(_ n: Int) {
		assert(Thread.isMainThread)
		numberOfTasks = numberOfTasks + n
		numberRemaining = numberRemaining + n
	}

	func completeTask() {
		assert(Thread.isMainThread)
		if numberRemaining > 0 {
			numberRemaining = numberRemaining - 1
		}
	}
	
	func completeTasks(_ tasks: Int) {
		assert(Thread.isMainThread)
		if numberRemaining >= tasks {
			numberRemaining = numberRemaining - tasks
		}
	}
	
	func reset() {
		assert(Thread.isMainThread)
		numberRemaining = 0
		numberOfTasks = 0
	}
}

// MARK: - Private

private extension DownloadProgress {
	func postDidChangeNotification() {
		NotificationCenter.default.post(name: .DownloadProgressDidChange, object: self)
	}
}

// MARK: - ProgressInfo

extension DownloadProgress {
	var progressInfo: ProgressInfo {
		ProgressInfo(numberOfTasks: numberOfTasks,
					 numberCompleted: numberCompleted,
					 numberRemaining: numberRemaining)
	}
}
