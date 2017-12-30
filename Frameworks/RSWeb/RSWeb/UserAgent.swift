//
//  UserAgent.swift
//  RSWeb
//
//  Created by Brent Simmons on 8/27/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct UserAgent {
	
	public static func fromInfoPlist() -> String? {

		guard let userAgentName = Bundle.main.object(forInfoDictionaryKey: "UserAgent") else {
			return nil
		}
		guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") else {
			return nil
		}

		if let userAgentParentheticalAddition = Bundle.main.object(forInfoDictionaryKey: "UserAgentParentheticalAddition") {
			return "\(userAgentName)/\(version) (\(userAgentParentheticalAddition))"
		}

		#if os(macOS)
			let osString = "Macintosh"
		#elseif os(iOS)
			let osString = "iOS"
		#endif

		return "\(userAgentName)/\(version) (\(osString))"
	}

	public static func headers() -> [AnyHashable: String]? {

		guard let userAgent = fromInfoPlist() else {
			return nil
		}

		return [HTTPRequestHeader.userAgent: userAgent]
	}
}
