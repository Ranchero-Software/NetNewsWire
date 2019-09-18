//
//  ArticleExtractorSecrets.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 9/18/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation

enum ArticleExtractorConfig {
	
	enum Mercury {
		// For testing add the environment variables in the scheme you are using
		static let clientId = ArticleExtractorConfig.environmentVariable(named: "MERCURY_CLIENT_ID") ?? Release.mercuryId
		static let clientSecret = ArticleExtractorConfig.environmentVariable(named: "MERCURY_CLIENT_SECRET") ?? Release.mercurySecret
		static let clientURL = Release.mercuryURL
	}
	
	private enum Release {
		static let mercuryId = "{MERCURYID}"
		static let mercurySecret = "{MERCURYSECRET}"
		static let mercuryURL = "https://extract.feedbin.com/parser"
	}
	
	private static func environmentVariable(named: String) -> String? {
		let processInfo = ProcessInfo.processInfo
		guard let value = processInfo.environment[named] else {
			print("‼️ Missing Environment Variable: '\(named)'")
			return nil
		}
		return value
	}
	
}
