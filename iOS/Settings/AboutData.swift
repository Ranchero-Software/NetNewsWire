//
//  AboutData.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 02/10/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import Foundation

struct AboutData: Codable {
	var AppCredits: [AppCredit]
	var AdditionalContributors: [Contributor]
	
	
	var ThanksMarkdown: AttributedString {
		let dataURL = Bundle.main.url(forResource: "Thanks", withExtension: "md")!
		return try! AttributedString(markdown: Data(contentsOf: dataURL), options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
	}
	
	struct AppCredit: Codable {
		var name: String
		var role: String
		var url: String?
	}
	
	struct Contributor: Codable {
		var name: String
		var url: String?
	}
	
}
