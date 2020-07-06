//
//  SettingsAboutModel.swift
//  Multiplatform iOS
//
//  Created by Maurice Parker on 7/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

class SettingsAboutModel: ObservableObject {
	
	var about: NSAttributedString
	var credits: NSAttributedString
	var thanks: NSAttributedString
	var dedication: NSAttributedString

	init() {
		about = SettingsAboutModel.loadResource("About")
		credits = SettingsAboutModel.loadResource("Credits")
		thanks = SettingsAboutModel.loadResource("Thanks")
		dedication = SettingsAboutModel.loadResource("Dedication")
	}
	
	private static func loadResource(_ resource: String) -> NSAttributedString {
		let url = Bundle.main.url(forResource: resource, withExtension: "rtf")!
		return try! NSAttributedString(url: url, options: [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)

	}
	
}
