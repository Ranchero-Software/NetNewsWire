//
//  ArticleThemesManager.sqift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/26/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Core

public extension Notification.Name {
	static let ArticleThemeNamesDidChangeNotification = Notification.Name("ArticleThemeNamesDidChangeNotification")
	static let CurrentArticleThemeDidChangeNotification = Notification.Name("CurrentArticleThemeDidChangeNotification")
}

final class ArticleThemesManager: NSObject, NSFilePresenter {

	@MainActor static var shared = ArticleThemesManager()
	public let folderURL: URL
	private var folderPath: String {
		folderURL.path
	}

	lazy var presentedItemOperationQueue = OperationQueue.main
	var presentedItemURL: URL? {
		folderURL
	}

	var currentThemeName: String {
		get {
			return AppDefaults.shared.currentThemeName ?? AppDefaults.defaultThemeName
		}
		set {
			if newValue != currentThemeName {
				AppDefaults.shared.currentThemeName = newValue
				updateThemeNames()
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

	override init() {
		self.folderURL = AppConfig.dataSubfolder(named: "Themes")
		self.currentTheme = ArticleTheme.defaultTheme

		super.init()
		
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
	}
	
	func articleThemeWithThemeName(_ themeName: String) -> ArticleTheme? {
		if themeName == AppDefaults.defaultThemeName {
			return ArticleTheme.defaultTheme
		}
		
		let path: String
		let isAppTheme: Bool
		if let appThemePath = Bundle.main.url(forResource: themeName, withExtension: ArticleTheme.nnwThemeSuffix)?.path {
			path = appThemePath
			isAppTheme = true
		} else if let installedPath = pathForThemeName(themeName, folder: folderPath) {
			path = installedPath
			isAppTheme = false
		} else {
			return nil
		}
		
		do {
			return try ArticleTheme(path: path, isAppTheme: isAppTheme)
		} catch {
			NotificationCenter.default.post(name: .didFailToImportThemeWithError, object: nil, userInfo: ["error": error])
			return nil
		}
		
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
		let appThemeFilenames = Bundle.main.paths(forResourcesOfType: ArticleTheme.nnwThemeSuffix, inDirectory: nil)
		let appThemeNames = Set(appThemeFilenames.map { ArticleTheme.themeNameForPath($0) })

		let installedThemeNames = Set(allThemePaths(folderPath).map { ArticleTheme.themeNameForPath($0) })

		let allThemeNames = appThemeNames.union(installedThemeNames)
		
		let sortedThemeNames = allThemeNames.sorted(by: { $0.compare($1, options: .caseInsensitive) == .orderedAscending })
		if sortedThemeNames != themeNames {
			themeNames = sortedThemeNames
		}
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
	
}
