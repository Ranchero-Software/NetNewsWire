//
//  ArticleTheme.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/26/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import UniformTypeIdentifiers

public extension UTType {
	static var nnwTheme: UTType {
		UTType("com.ranchero.netnewswire.theme")!
	}
}

struct ArticleTheme: Equatable {
	
	static let defaultTheme = ArticleTheme()
	static let nnwThemeSuffix = ".nnwtheme"
	
	private static let defaultThemeName = NSLocalizedString("DEFAULT", comment: "Default")
	private static let unknownValue = NSLocalizedString("UNKNOWN", comment: "Unknown Value")
	
	let path: String?
	let template: String?
	let css: String?
	let isAppTheme: Bool
	
	var name: String {
		guard let path = path else { return Self.defaultThemeName }
		return Self.themeNameForPath(path)
	}
	
	var creatorHomePage: String {
		return info?.creatorHomePage ?? Self.unknownValue
	}
	
	var creatorName: String {
		return info?.creatorName ?? Self.unknownValue
	}
	
	var version: String {
		return String(describing: info?.version ?? 0)
	}
	
	private let info: ArticleThemePlist?
	
	init() {
		self.path = nil;
		self.info = ArticleThemePlist(name: "Article Theme", themeIdentifier: "com.ranchero.netnewswire.theme.article", creatorHomePage: "https://netnewswire.com/", creatorName: "Ranchero Software", version: 1)
		
		let corePath = Bundle.main.path(forResource: "core", ofType: "css")!
		let stylesheetPath = Bundle.main.path(forResource: "stylesheet", ofType: "css")!
		css = Self.stringAtPath(corePath)! + "\n" + Self.stringAtPath(stylesheetPath)!
		
		let templatePath = Bundle.main.path(forResource: "template", ofType: "html")!
		template = Self.stringAtPath(templatePath)!
		
		isAppTheme = true
	}
	
	init(path: String, isAppTheme: Bool) throws {
		self.path = path
		
		let infoPath = (path as NSString).appendingPathComponent("Info.plist")
		let data = try Data(contentsOf: URL(fileURLWithPath: infoPath))
		self.info = try PropertyListDecoder().decode(ArticleThemePlist.self, from: data)
		
		let corePath = Bundle.main.path(forResource: "core", ofType: "css")!
		let stylesheetPath = (path as NSString).appendingPathComponent("stylesheet.css")
		if let stylesheetCSS = Self.stringAtPath(stylesheetPath) {
			self.css = Self.stringAtPath(corePath)! + "\n" + stylesheetCSS
		} else {
			self.css = nil
		}
		
		let templatePath = (path as NSString).appendingPathComponent("template.html")
		self.template = Self.stringAtPath(templatePath)
		
		self.isAppTheme = isAppTheme
	}
	
	static func stringAtPath(_ f: String) -> String? {
		if !FileManager.default.fileExists(atPath: f) {
			return nil
		}
		
		if let s = try? NSString(contentsOfFile: f, usedEncoding: nil) as String {
			return s
		}
		return nil
	}
	
	static func filenameWithThemeSuffixRemoved(_ filename: String) -> String {
		return filename.stripping(suffix: Self.nnwThemeSuffix)
	}
	
	static func themeNameForPath(_ f: String) -> String {
		let filename = (f as NSString).lastPathComponent
		return filenameWithThemeSuffixRemoved(filename)
	}
	
	static func pathIsPathForThemeName(_ themeName: String, path: String) -> Bool {
		let filename = (path as NSString).lastPathComponent
		return filenameWithThemeSuffixRemoved(filename) == themeName
	}
	
}
