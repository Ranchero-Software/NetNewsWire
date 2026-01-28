//
//  Bundle-Extensions.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/26/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation

public extension Bundle {
	var appName: String {
		infoDictionary?["CFBundleName"] as! String
	}

	var versionNumber: String {
		infoDictionary?["CFBundleShortVersionString"] as! String
	}

	var buildNumber: String {
		infoDictionary?["CFBundleVersion"] as! String
	}
}
