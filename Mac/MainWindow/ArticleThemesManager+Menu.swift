//
//  ArticleThemesManager+Menu.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/13/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import AppKit

extension ArticleThemesManager {

	/// The default theme, a separator, then the other themes. The current theme is checked.
	@MainActor func makeArticleThemeMenu() -> NSMenu {
		let articleThemeMenu = NSMenu()

		func addThemeItem(_ themeName: String) {
			let themeItem = NSMenuItem()
			themeItem.title = themeName
			themeItem.action = #selector(MainWindowController.selectArticleTheme(_:))
			themeItem.state = themeName == currentThemeName ? .on : .off
			articleThemeMenu.addItem(themeItem)
		}

		addThemeItem(ArticleTheme.defaultTheme.name)
		articleThemeMenu.addItem(NSMenuItem.separator())
		for themeName in themeNames {
			addThemeItem(themeName)
		}

		return articleThemeMenu
	}
}
