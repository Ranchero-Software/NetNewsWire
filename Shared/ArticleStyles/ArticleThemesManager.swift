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

final class ArticleThemesManager: NSObject, NSFilePresenter, Logging {

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
				currentTheme = articleThemeWithThemeName(newValue)
			}
		}
	}

	lazy var currentTheme = { articleThemeWithThemeName(currentThemeName) }() {
		didSet {
			NotificationCenter.default.post(name: .CurrentArticleThemeDidChangeNotification, object: self)
		}
	}

	lazy var themeNames = { buildThemeNames() }() {
		didSet {
			NotificationCenter.default.post(name: .ArticleThemeNamesDidChangeNotification, object: self)
		}
	}

	init(folderPath: String) {
		self.folderPath = folderPath

		super.init()
		
		do {
			try FileManager.default.createDirectory(atPath: folderPath, withIntermediateDirectories: true, attributes: nil)
		} catch {
			logger.error("Could not create folder for themes: \(error.localizedDescription, privacy: .public)")
			assertionFailure("Could not create folder for Themes.")
			abort()
		}
		
		NSFileCoordinator.addFilePresenter(self)
	}
	
	func presentedSubitemDidChange(at url: URL) {
		themeNames = buildThemeNames()
		currentTheme = articleThemeWithThemeName(currentThemeName)
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
	
	func articleThemeWithThemeName(_ themeName: String) -> ArticleTheme {
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
			return ArticleTheme.defaultTheme
		}
		
		do {
			return try ArticleTheme(path: path, isAppTheme: isAppTheme)
		} catch {
			NotificationCenter.default.post(name: .didFailToImportThemeWithError, object: nil, userInfo: ["error": error])
			logger.error("Failed to import theme: \(error.localizedDescription, privacy: .public)")
			return ArticleTheme.defaultTheme
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

	func buildThemeNames() -> [String] {
		let appThemeFilenames = Bundle.main.paths(forResourcesOfType: ArticleTheme.nnwThemeSuffix, inDirectory: nil)
		let appThemeNames = Set(appThemeFilenames.map { ArticleTheme.themeNameForPath($0) })

		let installedThemeNames = Set(allThemePaths(folderPath).map { ArticleTheme.themeNameForPath($0) })

		let allThemeNames = appThemeNames.union(installedThemeNames)
		
		return allThemeNames.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
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
