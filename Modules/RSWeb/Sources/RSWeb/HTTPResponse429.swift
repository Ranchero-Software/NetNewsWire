//
//  File.swift
//  RSWeb
//
//  Created by Brent Simmons on 11/24/24.
//

import Foundation

// 429 Too Many Requests

struct HTTPResponse429 {

	let url: URL
	let host: String // lowercased
	let dateCreated: Date
	let retryAfter: TimeInterval

	var resumeDate: Date {
		dateCreated + TimeInterval(retryAfter)
	}
	var canResume: Bool {
		// Not >=, which is back-deployed and crashes on iOS 27.2 betas.
		Date() > resumeDate
	}

	init?(url: URL, retryAfter: TimeInterval) {

		guard let host = url.host() else {
			return nil
		}

		self.url = url
		self.host = host.lowercased(with: localeForLowercasing)
		self.retryAfter = retryAfter
		self.dateCreated = Date()
	}
}
