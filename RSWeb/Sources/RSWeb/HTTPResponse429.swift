//
//  File.swift
//  RSWeb
//
//  Created by Brent Simmons on 11/24/24.
//

import Foundation

// 429 Too Many Requests

final class HTTPResponse429 {

	let url: URL
	let host: String // lowercased
	let retryAfterSeconds: Int
	let dateMessageReceived: Date
	let resumeDate: Date // dateMessageReceived + retryAfterSeconds

	init?(url: URL, retryAfterSeconds: Int) {

		guard let host = url.host() else {
			return nil
		}

		self.url = url
		self.host = host.lowercased()
		self.retryAfterSeconds = retryAfterSeconds

		let currentDate = Date()
		self.dateMessageReceived = currentDate
		self.resumeDate = currentDate + TimeInterval(retryAfterSeconds)
	}
}
