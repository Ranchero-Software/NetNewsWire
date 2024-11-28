//
//  DownloadProgress.swift
//  RSWeb
//
//  Created by Brent Simmons on 9/17/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// Main thread only.

public extension Notification.Name {
	
	static let DownloadProgressDidChange = Notification.Name(rawValue: "DownloadProgressDidChange")
}

public final class DownloadProgress {
	
	public var numberOfTasks = 0 {
		didSet {
			if numberOfTasks == 0 && numberRemaining != 0 {
				numberRemaining = 0
			}
			if numberOfTasks != oldValue {
				postDidChangeNotification()
			}
		}
	}
	
	public var numberRemaining = 0 {
		didSet {
			if numberRemaining != oldValue {
				postDidChangeNotification()
			}
		}
	}

	public var numberCompleted: Int {
		var n = numberOfTasks - numberRemaining
		if n < 0 {
			n = 0
		}
		if n > numberOfTasks {
			n = numberOfTasks
		}
		return n
	}
	
	public var isComplete: Bool {
		assert(Thread.isMainThread)
		return numberRemaining < 1
	}
	
	public init(numberOfTasks: Int) {
		assert(Thread.isMainThread)
		self.numberOfTasks = numberOfTasks
	}
	
	public func addToNumberOfTasks(_ n: Int) {
		assert(Thread.isMainThread)
		numberOfTasks = numberOfTasks + n
	}
	
	public func addToNumberOfTasksAndRemaining(_ n: Int) {
		assert(Thread.isMainThread)
		numberOfTasks = numberOfTasks + n
		numberRemaining = numberRemaining + n
	}

	public func completeTask() {
		assert(Thread.isMainThread)
		if numberRemaining > 0 {
			numberRemaining = numberRemaining - 1
		}
	}
	
	public func completeTasks(_ tasks: Int) {
		assert(Thread.isMainThread)
		if numberRemaining >= tasks {
			numberRemaining = numberRemaining - tasks
		}
	}
	
	public func clear() {
		assert(Thread.isMainThread)
		numberOfTasks = 0
	}
}

// MARK: - Private

private extension DownloadProgress {
	
	func postDidChangeNotification() {
		DispatchQueue.main.async {
			NotificationCenter.default.post(name: .DownloadProgressDidChange, object: self)
		}
	}
}
