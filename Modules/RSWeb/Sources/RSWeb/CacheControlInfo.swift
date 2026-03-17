//
//  CacheControl.swift
//  RSWeb
//
//  Created by Brent Simmons on 11/30/24.
//

import Foundation

/// Basic Cache-Control handling — just the part we need,
/// which is to know when we got the response (dateCreated)
/// and when we can ask again (canResume).
public struct CacheControlInfo: Codable, Equatable, Sendable {

	public let dateCreated: Date
	public let maxAge: TimeInterval

	var resumeDate: Date {
		dateCreated + maxAge
	}
	public var canResume: Bool {
		Date() >= resumeDate
	}

	/// canResume with a maximum maxAge. We do this because
	/// sites tend to misconfigure their max age — we’ve seen
	/// feeds that make this as long as one year, which is
	/// clearly not intentional.
	public func canResume(maxMaxAge: TimeInterval) -> Bool {
		let maxAgeToUse = min(maxMaxAge, maxAge)
		return Date() >= dateCreated + maxAgeToUse
	}

	public init(dateCreated: Date, maxAge: TimeInterval) {
		self.dateCreated = dateCreated
		self.maxAge = maxAge
	}

	public init?(urlResponse: HTTPURLResponse) {
		guard let cacheControlValue = urlResponse.valueForHTTPHeaderField(HTTPResponseHeader.cacheControl) else {
			return nil
		}
		self.init(value: cacheControlValue)
	}

	/// Returns nil if there’s no max-age or it’s < 1.
	public init?(value: String) {

		guard let maxAge = Self.parseMaxAge(value) else {
			return nil
		}

		let d = Date()
		self.dateCreated = d
		self.maxAge = maxAge
	}
}

private extension CacheControlInfo {

	static let maxAgePrefix = "max-age="
	static let maxAgePrefixCount = maxAgePrefix.count

	static func parseMaxAge(_ s: String) -> TimeInterval? {

		let components = s.components(separatedBy: ",")
		let trimmedComponents = components.map { $0.trimmingCharacters(in: .whitespaces) }

		for component in trimmedComponents {
			if component.hasPrefix(Self.maxAgePrefix) {
				let maxAgeStringValue = component.dropFirst(maxAgePrefixCount)
				if let timeInterval = TimeInterval(maxAgeStringValue), timeInterval > 0 {
					return timeInterval
				}
			}
		}

		return nil
	}
}
