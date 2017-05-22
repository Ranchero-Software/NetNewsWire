//
//  UserAgent.swift
//  RSWeb
//
//  Created by Brent Simmons on 8/27/16.
//  Copyright © 2016 Ranchero Software. All rights reserved.
//

import Foundation

public class UserAgent {
	
	public class func fromInfoPlist() -> String? {

		guard let userAgentName = Bundle.main.object(forInfoDictionaryKey: "UserAgent") else {
			return nil
		}
		guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") else {
			return nil
		}
		return "\(userAgentName) \(version)"
	}
}
