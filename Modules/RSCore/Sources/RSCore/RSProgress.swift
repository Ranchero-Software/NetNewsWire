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

/// Tracks how much work is left to do, in arbitrary "tasks".
///
/// All counts are *estimates* — callers don't have to predict exactly how many
/// tasks they'll add or complete. After every mutation the three counts are
/// normalized so that:
///
/// - `numberOfTasks`, `numberCompleted`, and `numberRemaining` are all `>= 0`
/// - `numberOfTasks == numberCompleted + numberRemaining`
///
/// If the work outgrows the estimate (more completions than added tasks, or a
/// negative count is passed), the counts are adjusted to stay consistent.
/// The progress bar may jump as the estimate catches up to reality,
/// but the numbers will never be nonsense.
@MainActor public final class RSProgress: ProgressInfoReporter {
	public private(set) var numberOfTasks = 0
	public private(set) var numberCompleted = 0
	public private(set) var numberRemaining = 0
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
		numberRemaining < 1
	}

	/// `numberOfTasks` is an estimate; pass 0 if unknown.
	public init(numberOfTasks: Int = 0) {
		self.numberOfTasks = max(0, numberOfTasks)
		self.numberRemaining = self.numberOfTasks
	}

	/// Directly set the number of remaining tasks, instead of calling `completeTasks`.
	/// Updates `numberCompleted`. Negative values are treated as 0; values larger
	/// than `numberOfTasks` grow `numberOfTasks` to match.
	public func updateNumberRemaining(_ newNumberRemaining: Int) {
		let clamped = max(0, newNumberRemaining)
		if clamped == numberRemaining {
			return
		}

		numberRemaining = clamped
		if numberCompleted + numberRemaining > numberOfTasks {
			numberOfTasks = numberCompleted + numberRemaining
		} else {
			numberCompleted = numberOfTasks - numberRemaining
		}
		updateProgressInfo()
	}

	/// Directly set the number of completed tasks, instead of calling `completeTasks`.
	/// Updates `numberRemaining`. Negative values are treated as 0; values larger
	/// than `numberOfTasks` grow `numberOfTasks` to match.
	public func updateNumberCompleted(_ newNumberCompleted: Int) {
		let clamped = max(0, newNumberCompleted)
		if clamped == numberCompleted {
			return
		}

		numberCompleted = clamped
		if numberCompleted > numberOfTasks {
			numberOfTasks = numberCompleted
		}
		numberRemaining = numberOfTasks - numberCompleted
		updateProgressInfo()
	}

	/// Adds to the estimated task total. Negative values are ignored.
	public func addTasks(_ count: Int) {
		guard count > 0 else {
			return
		}
		numberOfTasks += count
		numberRemaining = numberOfTasks - numberCompleted
		updateProgressInfo()
	}

	public func addTask() {
		addTasks(1)
	}

	/// Marks `count` more tasks complete. Negative values are ignored.
	/// If completion exceeds the estimate, `numberOfTasks` grows to match so
	/// the invariant holds.
	public func completeTasks(_ count: Int) {
		guard count > 0 else {
			return
		}
		numberCompleted += count
		if numberCompleted > numberOfTasks {
			numberOfTasks = numberCompleted
		}
		numberRemaining = numberOfTasks - numberCompleted
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
