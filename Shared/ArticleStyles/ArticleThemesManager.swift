//
//  ArticleThemesManager.sqift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/26/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore

public extension Notification.Name {
	static let ArticleThemeNamesDidChangeNotification = Notification.Name("ArticleThemeNamesDidChangeNotification")
	static let CurrentArticleThemeDidChangeNotification = Notification.Name("CurrentArticleThemeDidChangeNotification")
}

final class ArticleThemesManager: NSObject, NSFilePresenter {

	static var shared: ArticleThemesManager!
	public let folderPath: String

	lazy var presentedItemOperationQueue = OperationQueue.main
	var presentedItemURL: URL? {
		return URL(fileURLWithPath: folderPath)
	}

	var currentThemeName: String {
		get {
			return AppDefaults.shared.currentThemeName ?? AppDefaults.defaultThemeName
		}
		set {
			if newValue != currentThemeName {
				AppDefaults.shared.currentThemeName = newValue
				updateCurrentTheme()
			}
		}
	}

	var currentTheme: ArticleTheme {
		didSet {
			NotificationCenter.default.post(name: .CurrentArticleThemeDidChangeNotification, object: self)
		}
	}

	var themeNames = [AppDefaults.defaultThemeName] {
		didSet {
			NotificationCenter.default.post(name: .ArticleThemeNamesDidChangeNotification, object: self)
		}
	}

	init(folderPath: String) {
		self.folderPath = folderPath
		self.currentTheme = ArticleTheme.defaultTheme

		super.init()
		
		do {
			try FileManager.default.createDirectory(atPath: folderPath, withIntermediateDirectories: true, attributes: nil)
		} catch {
			assertionFailure("Could not create folder for Themes.")
			abort()
		}
		
		let themeFilenames = Bundle.main.paths(forResourcesOfType: ArticleTheme.nnwThemeSuffix, inDirectory: nil)
		let installedStyleSheets = readInstalledStyleSheets() ?? [String: Date]()
		for themeFilename in themeFilenames {
			let themeName = ArticleTheme.themeNameForPath(themeFilename)
			if !installedStyleSheets.keys.contains(themeName) {
				try? importTheme(filename: themeFilename)
			}
		}

		updateThemeNames()
		updateCurrentTheme()

		NSFileCoordinator.addFilePresenter(self)
	}
	
	func presentedSubitemDidChange(at url: URL) {
		updateThemeNames()
		updateCurrentTheme()
	}

	// MARK: API
	
	func themeExists(filename: String) -> Bool {
		let filenameLastPathComponent = (filename as NSString).lastPathComponent
		let toFilename = (folderPath as NSString).appendingPathComponent(filenameLastPathComponent)
		return FileManager.default.fileExists(atPath: toFilename)
	}
	
	func importTheme(filename: String) throws {
		let filenameLastPathComponent = (filename as NSString).lastPathComponent
		let toFilename = (folderPath as NSString).appendingPathComponent(filenameLastPathComponent)
		
		if FileManager.default.fileExists(atPath: toFilename) {
			try FileManager.default.removeItem(atPath: toFilename)
		}
		
		try FileManager.default.copyItem(atPath: filename, toPath: toFilename)

		let themeName = ArticleTheme.themeNameForPath(filename)
		var installedStyleSheets = readInstalledStyleSheets() ?? [String: Date]()
		installedStyleSheets[themeName] = Date()
		writeInstalledStyleSheets(installedStyleSheets)
	}
	
	func deleteTheme(themeName: String) {
		if let filename = pathForThemeName(themeName, folder: folderPath) {
			try? FileManager.default.removeItem(atPath: filename)
		}
	}
	
}

// MARK : Private

private extension ArticleThemesManager {

	func updateThemeNames() {
		let updatedThemeNames = allThemePaths(folderPath).map { ArticleTheme.themeNameForPath($0) }
		let sortedThemeNames = updatedThemeNames.sorted(by: { $0.compare($1, options: .caseInsensitive) == .orderedAscending })
		if sortedThemeNames != themeNames {
			themeNames = sortedThemeNames
		}
	}

	func articleThemeWithThemeName(_ themeName: String) -> ArticleTheme? {
		if themeName == AppDefaults.defaultThemeName {
			return ArticleTheme.defaultTheme
		}
		
		guard let path = pathForThemeName(themeName, folder: folderPath) else {
			return nil
		}

		return try? ArticleTheme(path: path)
	}

	func defaultArticleTheme() -> ArticleTheme {
		return articleThemeWithThemeName(AppDefaults.defaultThemeName)!
	}

	func updateCurrentTheme() {
		var themeName = currentThemeName
		if !themeNames.contains(themeName) {
			themeName = AppDefaults.defaultThemeName
			currentThemeName = AppDefaults.defaultThemeName
		}

		var articleTheme = articleThemeWithThemeName(themeName)
		if articleTheme == nil {
			articleTheme = defaultArticleTheme()
			currentThemeName = AppDefaults.defaultThemeName
		}

		if let articleTheme = articleTheme, articleTheme != currentTheme {
			currentTheme = articleTheme
		}
	}

	func allThemePaths(_ folder: String) -> [String] {
		let filepaths = FileManager.default.filePaths(inFolder: folder)
		return filepaths?.filter { $0.hasSuffix(ArticleTheme.nnwThemeSuffix) } ?? []
	}

	func pathForThemeName(_ themeName: String, folder: String) -> String? {
		for onePath in allThemePaths(folder) {
			if ArticleTheme.pathIsPathForThemeName(themeName, path: onePath) {
				return onePath
			}
		}
		return nil
	}
	
	func readInstalledStyleSheets() -> [String: Date]? {
		let filePath = (folderPath as NSString).appendingPathComponent("InstalledStyleSheets.plist")
		return NSDictionary(contentsOfFile: filePath) as? [String: Date]
	}
	
	func writeInstalledStyleSheets(_ dict: [String: Date]) {
		let filePath = (folderPath as NSString).appendingPathComponent("InstalledStyleSheets.plist")
		(dict as NSDictionary).write(toFile: filePath, atomically: true)
	}
	
}
