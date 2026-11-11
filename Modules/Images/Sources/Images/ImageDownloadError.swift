//
//  ImageDownloadError.swift
//  Images
//
//  Created by Brent Simmons on 11/3/26.
//

import Foundation

public struct ImageDownloadError: Error {
	public let statusCode: Int?
	public let decodingFailed: Bool
	public let isTransient: Bool // No network, DNS issues, timeout, 5xx, 429, or 408 response, etc.
	public let rejectedPixelSize: (width: Int, height: Int)? // Too small or too narrow to be a thumbnail
	public let retryAfter: TimeInterval? // From a Retry-After header in seconds
	public let rejectedByteCount: Int? // Too large to save for the timeline

	/// No request was made: waiting to retry, dropped from the download queue, or the network doesn’t allow the download.
	static let notAttempted = ImageDownloadError(statusCode: nil, decodingFailed: false, isTransient: true)

	init(statusCode: Int?, decodingFailed: Bool, isTransient: Bool, rejectedPixelSize: (width: Int, height: Int)? = nil, retryAfter: TimeInterval? = nil, rejectedByteCount: Int? = nil) {
		self.statusCode = statusCode
		self.decodingFailed = decodingFailed
		self.isTransient = isTransient
		self.rejectedPixelSize = rejectedPixelSize
		self.retryAfter = retryAfter
		self.rejectedByteCount = rejectedByteCount
	}
}

extension ImageDownloadError: LocalizedError {
	public var errorDescription: String? {
		if let rejectedByteCount {
			return "Image too large (\(rejectedByteCount) bytes)"
		}
		if let rejectedPixelSize {
			return "Image too small or too narrow (\(rejectedPixelSize.width)×\(rejectedPixelSize.height))"
		}
		if decodingFailed {
			if let statusCode {
				return "Couldn’t decode image bytes (HTTP \(statusCode))"
			}
			return "Couldn’t decode image bytes"
		}
		guard let statusCode else {
			return isTransient ? "No response" : "Bad URL"
		}
		return "HTTP \(statusCode)"
	}
}
