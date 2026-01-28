//
//  RSProgress.swift
//  RSCore
//
//  Created by Brent Simmons on 1/2/26.
//

import Foundation

public struct ProgressInfo: Sendable, Equatable {
	public let numberOfTasks: Int
	public let numberCompleted: Int
	public let numberRemaining: Int

	public var isComplete: Bool {
		numberRemaining < 1
	}

	public init(numberOfTasks: Int = 0, numberCompleted: Int = 0, numberRemaining: Int = 0) {
		assert(numberOfTasks >= 0 && numberCompleted >= 0 && numberRemaining >= 0)
		assert(numberOfTasks == numberCompleted + numberRemaining)

		self.numberOfTasks = numberOfTasks
		self.numberCompleted = numberCompleted
		self.numberRemaining = numberRemaining
	}

	public static func combined(_ progressInfos: [ProgressInfo]) -> ProgressInfo {
		var numberOfTasks = 0
		var numberCompleted = 0
		var numberRemaining = 0

		for progressInfo in progressInfos {
			numberOfTasks += progressInfo.numberOfTasks
			numberCompleted += progressInfo.numberCompleted
			numberRemaining += progressInfo.numberRemaining
		}

		return ProgressInfo(numberOfTasks: numberOfTasks,
							numberCompleted: numberCompleted,
							numberRemaining: numberRemaining)
	}
}

/// A ProgressInfoReporter provides a ProgressInfo struct and sends a .progressDidChange notification.
@MainActor public protocol ProgressInfoReporter: AnyObject {
	var progressInfo: ProgressInfo { get }
}

public extension Notification.Name {
	static let progressInfoDidChange = Notification.Name(rawValue: "ProgressInfoDidChangeNotification")
}

@MainActor public extension ProgressInfoReporter {
	func postProgressInfoDidChangeNotification() {
		NotificationCenter.default.post(name: .progressInfoDidChange, object: self)
	}
}

@MainActor public final class RSProgress: ProgressInfoReporter {
	public var numberOfTasks = 0
	public var numberCompleted = 0
	public var numberRemaining = 0
	public var children: [RSProgress]?

	/// Report progress including all children.
	public var progressInfo = ProgressInfo() {
		didSet {
			if progressInfo != oldValue {
				postProgressInfoDidChangeNotification()
			}
		}
	}

	public var hasNoRemainingTasks: Bool {
		assert(numberRemaining >= 0)
		return numberRemaining < 1
	}

	public init(numberOfTasks: Int = 0) {
		assert(numberOfTasks >= 0)
		self.numberOfTasks = numberOfTasks
	}

	/// Directly set the number of remaining tasks, instead of calling `completeTasks`.
	/// Updates `numberCompleted`.
	public func updateNumberRemaining(_ newNumberRemaining: Int) {
		if newNumberRemaining == numberRemaining {
			return
		}

		assert(newNumberRemaining <= numberOfTasks)
		numberRemaining = newNumberRemaining
		numberCompleted = numberOfTasks - numberRemaining
		updateProgressInfo()
	}

	/// Directly set the number of completed tasks, instead of calling `completeTasks`.
	/// Updates `numberRemaining`.
	public func updateNumberCompleted(_ newNumberCompleted: Int) {
		if newNumberCompleted == numberCompleted {
			return
		}

		assert(newNumberCompleted <= numberOfTasks)
		numberCompleted = newNumberCompleted
		numberRemaining = numberOfTasks - numberCompleted
		updateProgressInfo()
	}

	public func addTasks(_ count: Int) {
		numberOfTasks += count
		numberRemaining += count
		updateProgressInfo()
	}

	public func addTask() {
		addTasks(1)
	}

	public func completeTasks(_ count: Int) {
		numberCompleted += count

		numberRemaining -= count
		assert(numberRemaining >= 0)
		if numberRemaining < 0 {
			numberRemaining = 0
		}

		assert(numberOfTasks == numberRemaining + numberCompleted)
		updateProgressInfo()
	}

	public func completeTask() {
		completeTasks(1)
	}

	public func completeAll() {
		numberCompleted = numberOfTasks
		numberRemaining = 0
		updateProgressInfo()
	}

	public func reset() {
		numberOfTasks = 0
		numberCompleted = 0
		numberRemaining = 0
		updateProgressInfo()
	}

	public func addChild(_ child: RSProgress) {
		children = (children ?? []) + [child]
		updateProgressInfo()
	}
}

private extension RSProgress {
	func updateProgressInfo() {
		var numberOfTasks = self.numberOfTasks
		var numberCompleted = self.numberCompleted
		var numberRemaining = self.numberRemaining

		if let children {
			for child in children {
				let childProgressInfo = child.progressInfo
				numberOfTasks += childProgressInfo.numberOfTasks
				numberCompleted += childProgressInfo.numberCompleted
				numberRemaining += childProgressInfo.numberRemaining
			}
		}

		progressInfo = ProgressInfo(numberOfTasks: numberOfTasks,
									numberCompleted: numberCompleted,
									numberRemaining: numberRemaining)
	}
}
