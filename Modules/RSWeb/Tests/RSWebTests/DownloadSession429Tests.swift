//
//  DownloadSession429Tests.swift
//  RSWebTests
//
//  Created by Brent Simmons on 9/17/26.
//

import Foundation
import Testing
@testable import RSWeb

/// After a 429 Too Many Requests, the session throttles the host and cancels
/// its other tasks. Both are keyed by host, and both must match the host
/// exactly, ignoring case.
@MainActor struct DownloadSession429Tests {

	@Test func throttleLookupIgnoresHostCase() throws {
		let session = DownloadSession(delegate: StubDownloadSessionDelegate())
		let mixedCaseURL = try #require(URL(string: "https://Example.com/feed"))
		let task = URLSession.shared.dataTask(with: mixedCaseURL)
		let response = try #require(HTTPURLResponse(url: mixedCaseURL, statusCode: 429, httpVersion: nil, headerFields: [HTTPResponseHeader.retryAfter: "60"]))

		session.handle429Response(task, response)

		#expect(session.requestShouldBeDroppedDueToActive429(mixedCaseURL))
		let lowercaseURL = try #require(URL(string: "https://example.com/other"))
		#expect(session.requestShouldBeDroppedDueToActive429(lowercaseURL))
		let otherHostURL = try #require(URL(string: "https://example.org/feed"))
		#expect(!session.requestShouldBeDroppedDueToActive429(otherHostURL))
	}

	@Test func cancellationMatchesExactHostOnly() throws {
		let sameHost = try task("https://t.co/a")
		let sameHostUppercase = try task("https://T.CO/b")
		let containingHost = try task("https://at.com/c")
		let subdomain = try task("https://feeds.t.co/d")
		let allTasks: Set<URLSessionTask> = [sameHost, sameHostUppercase, containingHost, subdomain]

		let matching = DownloadSession.tasksWithHost("t.co", in: allTasks)

		#expect(matching == [sameHost, sameHostUppercase])
	}
}

// MARK: - Helpers

private extension DownloadSession429Tests {

	func task(_ urlString: String) throws -> URLSessionTask {
		let url = try #require(URL(string: urlString))
		return URLSession.shared.dataTask(with: url)
	}
}

@MainActor private final class StubDownloadSessionDelegate: DownloadSessionDelegate {

	func downloadSession(_ downloadSession: DownloadSession, conditionalGetInfoFor: URL) -> HTTPConditionalGetInfo? {
		nil
	}

	func downloadSession(_ downloadSession: DownloadSession, didReceiveResponse url: URL) {
	}

	func downloadSession(_ downloadSession: DownloadSession, didSkip url: URL, reason: String) {
	}

	func downloadSession(_ downloadSession: DownloadSession, downloadDidComplete: URL, response: URLResponse?, data: Data, error: NSError?) {
	}

	func downloadSession(_ downloadSession: DownloadSession, shouldContinueAfterReceivingData: Data, url: URL) -> Bool {
		true
	}

	func downloadSession(_ downloadSession: DownloadSession, httpError statusCode: Int, url: URL) {
	}

	func downloadSession(_ downloadSession: DownloadSession, didFollowRedirectFor url: URL, from fromURL: URL, to toURL: URL, statusCode: Int) {
	}

	func downloadSessionDidComplete(_ downloadSession: DownloadSession) {
	}
}
