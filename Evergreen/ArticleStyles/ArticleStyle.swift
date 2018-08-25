//
//  ArticleStyle.swift
//  Evergreen
//
//  Created by Brent Simmons on 9/26/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct ArticleStyle: Equatable {

	static let defaultStyle = ArticleStyle()
	let path: String?
	let template: String?
	let css: String?
	let emptyCSS: String?
	let info: NSDictionary?

	init() {

		//Default style

		self.path = nil;
		self.emptyCSS = nil

		self.info = ["CreatorHomePage": "http://ranchero.com/", "CreatorName": "Ranchero Software, LLC", "Version": "1.0"]

		let cssPath = Bundle.main.path(forResource: "styleSheet", ofType: "css")!
		css = stringAtPath(cssPath)

		let templatePath = Bundle.main.path(forResource: "template", ofType: "html")!
		template = stringAtPath(templatePath)
	}

	init(path: String) {

		self.path = path

		let isFolder = FileManager.default.rs_fileIsFolder(path)

		if isFolder {

			let infoPath = (path as NSString).appendingPathComponent("Info.plist")
			self.info = NSDictionary(contentsOfFile: infoPath)

			let cssPath = (path as NSString).appendingPathComponent("stylesheet.css")
			self.css = stringAtPath(cssPath)

			let emptyCSSPath = (path as NSString).appendingPathComponent("stylesheet_empty.css")
			self.emptyCSS = stringAtPath(emptyCSSPath)

			let templatePath = (path as NSString).appendingPathComponent("template.html")
			self.template = stringAtPath(templatePath)
		}

		else {

			self.css = stringAtPath(path)
			self.template = nil
			self.emptyCSS = nil
			self.info = nil
		}
	}
}

private func stringAtPath(_ f: String) -> String? {

	if !FileManager.default.fileExists(atPath: f) {
		return nil
	}

	if let s = try? NSString(contentsOfFile: f, usedEncoding: nil) as String {
		return s
	}
	return nil
}
