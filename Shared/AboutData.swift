//
//  AboutData.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 02/10/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import Foundation

protocol LoadableAboutData {
	var about: AboutData { get }
}

extension LoadableAboutData {
	
	var about: AboutData {
		guard let path = Bundle.main.path(forResource: "About", ofType: "plist") else {
			fatalError("The about plist really should exist.")
		}
		let url = URL(fileURLWithPath: path)
		let data = try! Data(contentsOf: url)
		return try! PropertyListDecoder().decode(AboutData.self, from: data)
	}
	
}

struct AboutData: Codable {
	var PrimaryContributors: [Contributor]
	var AdditionalContributors: [Contributor]
	
	var ThanksMarkdown: AttributedString {
		let dataURL = Bundle.main.url(forResource: "Thanks", withExtension: "md")!
		return try! AttributedString(markdown: Data(contentsOf: dataURL), options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
	}
	
	struct Contributor: Codable {
		var name: String
		var url: String?
		var role: String?
	}
}
