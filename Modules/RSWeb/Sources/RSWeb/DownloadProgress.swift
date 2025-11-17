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

nonisolated public final class DownloadProgress: Hashable, Sendable {
	public struct ProgressInfo: Sendable {
		public let numberOfTasks: Int
		public let numberCompleted: Int
		public let numberRemaining: Int
	}

	private let id: Int
	private static let nextID = Mutex(0)

	private struct State {
		var numberOfTasks = 0
		var numberCompleted = 0

		var numberRemaining: Int {
			let n = numberOfTasks - numberCompleted
			assert(n >= 0)
			return n
		}

		var children = Set<DownloadProgress>()

		init(_ numberOfTasks: Int) {
			self.numberOfTasks = numberOfTasks
		}
	}

	private let state: Mutex<State>

	public init(numberOfTasks: Int) {
		assert(numberOfTasks >= 0)
		self.state = Mutex(State(numberOfTasks))
		self.id = Self.autoincrementingID()
	}

	public var progressInfo: ProgressInfo {
		var numberOfTasks = 0
		var numberCompleted = 0
		var numberRemaining = 0

		state.withLock { state in
			numberOfTasks = state.numberOfTasks
			numberCompleted = state.numberCompleted
			numberRemaining = state.numberRemaining

			for child in state.children {
				let childProgressInfo = child.progressInfo
				numberOfTasks += childProgressInfo.numberOfTasks
				numberCompleted += childProgressInfo.numberCompleted
				numberRemaining += childProgressInfo.numberRemaining
			}
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

	public func addChild(_ childDownloadProgress: DownloadProgress) {
		precondition(self != childDownloadProgress)
		state.withLock { state in
			_ = state.children.insert(childDownloadProgress)
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

	public func completeAll() {
		state.withLock { state in
			state.numberCompleted = state.numberOfTasks
			for child in state.children {
				child.completeAll()
			}
		}
	}

	@discardableResult
	public func reset() -> Bool {
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

			for child in state.children {
				didChange = child.reset()
			}

			if didChange {
				postDidChangeNotification()
			}
			return didChange
		}
	}

	// MARK: - Hashable

	public func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}

	// MARK - Equatable

	public static func ==(lhs: DownloadProgress, rhs: DownloadProgress) -> Bool {
		lhs.id == rhs.id
	}
}

// MARK: - Private

nonisolated private extension DownloadProgress {

	func postDidChangeNotification() {
		DispatchQueue.main.async {
			NotificationCenter.default.post(name: .DownloadProgressDidChange, object: self)
		}
	}

	static func autoincrementingID() -> Int {
		nextID.withLock { id in
			defer {
				id += 1
			}
			return id
		}
	}
}
