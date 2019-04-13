//
//  ArticleStylesManager.sqift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/26/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore

let ArticleStyleNamesDidChangeNotification = "ArticleStyleNamesDidChangeNotification"
let CurrentArticleStyleDidChangeNotification = "CurrentArticleStyleDidChangeNotification"

private let styleKey = "style"
private let defaultStyleName = "Default"
private let stylesFolderName = "Styles"
private let stylesInResourcesFolderName = "Styles"
private let styleSuffix = ".netnewswirestyle"
private let nnwStyleSuffix = ".nnwstyle"
private let cssStyleSuffix = ".css"
private let styleSuffixes = [styleSuffix, nnwStyleSuffix, cssStyleSuffix];

final class ArticleStylesManager {

	static let shared = ArticleStylesManager()
	private let folderPath = RSDataSubfolder(nil, stylesFolderName)!

	var currentStyleName: String {
		get {
			return UserDefaults.standard.string(forKey: styleKey)!
		}
		set {
			if newValue != currentStyleName {
				UserDefaults.standard.set(newValue, forKey: styleKey)
			}
		}
	}

	var currentStyle: ArticleStyle {
		didSet {
			NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentArticleStyleDidChangeNotification), object: self)
		}
	}

	var styleNames = [defaultStyleName] {
		didSet {
			NotificationCenter.default.post(name: Notification.Name(rawValue: ArticleStyleNamesDidChangeNotification), object: self)
		}
	}

	init() {

		UserDefaults.standard.register(defaults: [styleKey: defaultStyleName])
//
//		let defaultStylesFolder = (Bundle.main.resourcePath! as NSString).appendingPathComponent(stylesInResourcesFolderName)
//		do {
//			try FileManager.default.rs_copyFiles(inFolder: defaultStylesFolder, destination: folderPath)
//		}
//		catch {
//			print(error)
//		}

		currentStyle = ArticleStyle.defaultStyle

		updateStyleNames()
		updateCurrentStyle()

		NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: NSApplication.didBecomeActiveNotification, object: nil)
	}

	// MARK: Notifications

	@objc dynamic func applicationDidBecomeActive(_ note: Notification) {

		updateStyleNames()
		updateCurrentStyle()
	}

	// MARK : Internal

	private func updateStyleNames() {

		let updatedStyleNames = allStylePaths(folderPath).map { styleNameForPath($0) }

		if updatedStyleNames != styleNames {
			styleNames = updatedStyleNames
		}
	}

	private func articleStyleWithStyleName(_ styleName: String) -> ArticleStyle? {

		if styleName == defaultStyleName {
			return ArticleStyle.defaultStyle
		}
		
		guard let path = pathForStyleName(styleName, folder: folderPath) else {
			return nil
		}

		return ArticleStyle(path: path)
	}

	private func defaultArticleStyle() -> ArticleStyle {

		return articleStyleWithStyleName(defaultStyleName)!
	}

	private func updateCurrentStyle() {

		var styleName = currentStyleName
		if !styleNames.contains(styleName) {
			styleName = defaultStyleName
			currentStyleName = defaultStyleName
		}

		var articleStyle = articleStyleWithStyleName(styleName)
		if articleStyle == nil {
			articleStyle = defaultArticleStyle()
			currentStyleName = defaultStyleName
		}

		if let articleStyle = articleStyle, articleStyle != currentStyle {
			currentStyle = articleStyle
		}
	}
}


private func allStylePaths(_ folder: String) -> [String] {

	let filepaths = FileManager.default.rs_filepaths(inFolder: folder)
	return filepaths.filter { fileAtPathIsStyle($0) }
}

private func fileAtPathIsStyle(_ f: String) -> Bool {

	if !f.hasSuffix(styleSuffix) && !f.hasSuffix(nnwStyleSuffix) && !f.hasSuffix(cssStyleSuffix) {
		return false
	}

	if (f as NSString).lastPathComponent.hasPrefix(".") {
		return false
	}

	return true
}

private func filenameWithStyleSuffixRemoved(_ filename: String) -> String {

	for oneSuffix in styleSuffixes {
		if filename.hasSuffix(oneSuffix) {
			return (filename as NSString).rs_string(byStrippingSuffix: oneSuffix, caseSensitive: false)
		}
	}

	return filename
}

private func styleNameForPath(_ f: String) -> String {

	let filename = (f as NSString).lastPathComponent
	return filenameWithStyleSuffixRemoved(filename)
}

private func pathIsPathForStyleName(_ styleName: String, path: String) -> Bool {

	let filename = (path as NSString).lastPathComponent
	return filenameWithStyleSuffixRemoved(filename) == styleName
}

private func pathForStyleName(_ styleName: String, folder: String) -> String? {

	for onePath in allStylePaths(folder) {
		if pathIsPathForStyleName(styleName, path: onePath) {
			return onePath
		}
	}

	return nil
}
