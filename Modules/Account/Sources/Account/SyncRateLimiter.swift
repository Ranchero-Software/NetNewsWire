//
//  SyncRateLimiter.swift
//  Account
//
//  Created by Brent Simmons on 8/3/26.
//

import Foundation
import os
import RSWeb

/// Pauses syncing after a rate-limit response until the server’s Retry-After (or a default) elapses.
@MainActor final class SyncRateLimiter {

	/// When syncing may resume. Nil when not rate limited.
	private(set) var resumeDate: Date?

	private let serviceName: String
	private let treatsForbiddenAsRateLimited: Bool
	private let logger: Logger

	private static let defaultRetryAfter: TimeInterval = 60 * 60

	init(serviceName: String, treatsForbiddenAsRateLimited: Bool, logger: Logger) {
		self.serviceName = serviceName
		self.treatsForbiddenAsRateLimited = treatsForbiddenAsRateLimited
		self.logger = logger
	}

	/// True when a rate-limit response has paused syncing and the pause hasn’t expired.
	func shouldSkip() -> Bool {
		guard let resumeDate else {
			return false
		}
		guard resumeDate > Date() else {
			self.resumeDate = nil
			return false
		}
		logger.info("\(self.serviceName): skipping — rate limited until \(resumeDate)")
		return true
	}

	/// Pause syncing until the server’s Retry-After (or a default) and post one Error Log entry.
	func noteRateLimited(_ error: Error, account: Account, operation: String) {
		let alreadyRateLimited = (resumeDate ?? .distantPast) > Date()
		resumeDate = Date().addingTimeInterval(retryAfter(for: error) ?? Self.defaultRetryAfter)
		logger.error("\(self.serviceName): rate limited — pausing syncing until \(self.resumeDate ?? .distantPast)")

		if !alreadyRateLimited {
			account.postSyncError(error, operation: operation)
		}
	}

	func isRateLimitError(_ error: Error) -> Bool {
		if case WebserviceError.tooManyRequests = error {
			return true
		}
		if treatsForbiddenAsRateLimited, case WebserviceError.httpError(let status) = error, status == HTTPResponseCode.forbidden {
			return true
		}
		return false
	}

	private func retryAfter(for error: Error) -> TimeInterval? {
		if case WebserviceError.tooManyRequests(let retryAfter) = error {
			return retryAfter
		}
		return nil
	}
}
