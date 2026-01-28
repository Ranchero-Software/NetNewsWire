//
//  ArticleThemePlist.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 19/09/2021.
//  Copyright © 2021 Ranchero Software. All rights reserved.
//

import Foundation

public struct ArticleThemePlist: Codable, Equatable, Sendable {
	public let name: String
	public let themeIdentifier: String
	public let creatorHomePage: String
	public let creatorName: String
	public let version: Int

	enum CodingKeys: String, CodingKey {
		case name = "Name"
		case themeIdentifier = "ThemeIdentifier"
		case creatorHomePage = "CreatorHomePage"
		case creatorName = "CreatorName"
		case version = "Version"
	}
}
