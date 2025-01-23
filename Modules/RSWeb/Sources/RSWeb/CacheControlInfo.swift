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
public struct CacheControlInfo: Codable, Equatable {

	let dateCreated: Date
	let maxAge: TimeInterval

	var resumeDate: Date {
		dateCreated + maxAge
	}
	public var canResume: Bool {
		Date() >= resumeDate
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
