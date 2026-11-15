//
//  ArticleThemesView.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 11/14/26.
//

import SwiftUI
import UniformTypeIdentifiers
import RSCore

/// Lists the article themes: tap to choose one, swipe to delete one the user installed, and + to import one.
struct ArticleThemesView: View {

	/// Asks the user to confirm installing the theme file they picked.
	let importTheme: (URL) throws -> Void

	@State private var model = ArticleThemesModel()
	@State private var isShowingThemeImporter = false
	@State private var themeNamePendingDeletion: String?
	@State private var isShowingThemesGallery = false

	var body: some View {
		List {
			Section {
				themeRow(model.defaultThemeName)
			}
			if !model.installedThemeNames.isEmpty {
				Section {
					ForEach(model.installedThemeNames, id: \.self) { themeName in
						themeRow(themeName)
					}
				}
			}
			Section {
				Button(String(localized: "Themes Gallery", comment: "Themes Gallery")) {
					isShowingThemesGallery = true
				}
			}
		}
		.settingsAccentTint()
		.navigationTitle(String(localized: "Themes", comment: "Themes"))
		.toolbar {
			ToolbarItem(placement: .primaryAction) {
				Button(String(localized: "Import Theme", comment: "Import Theme"), systemImage: "plus") {
					isShowingThemeImporter = true
				}
			}
		}
		.fileImporter(isPresented: $isShowingThemeImporter, allowedContentTypes: [.netNewsWireTheme]) { result in
			if case .success(let url) = result {
				importThemeFile(url)
			}
		}
		.sheet(isPresented: $isShowingThemesGallery) {
			if let themesGalleryURL = URL(string: HelpURL.themesGallery.rawValue) {
				SafariView(url: themesGalleryURL)
			}
		}
		.alert(String(localized: "Delete Theme?", comment: "Delete Theme"), isPresented: isShowingDeleteThemeConfirmation, presenting: themeNamePendingDeletion) { themeName in
			Button(String(localized: "Cancel", comment: "Cancel button"), role: .cancel) {
			}
			Button(String(localized: "Delete", comment: "Delete button"), role: .destructive) {
				ArticleThemesManager.shared.deleteTheme(themeName: themeName)
			}
		} message: { themeName in
			Text(deleteThemeMessage(themeName))
		}
	}
}

// MARK: - Private

private extension ArticleThemesView {

	var isShowingDeleteThemeConfirmation: Binding<Bool> {
		Binding {
			themeNamePendingDeletion != nil
		} set: { isShowing in
			if !isShowing {
				themeNamePendingDeletion = nil
			}
		}
	}

	func themeRow(_ themeName: String) -> some View {
		let isCurrentTheme = themeName == model.currentThemeName
		return Button {
			ArticleThemesManager.shared.currentThemeName = themeName
		} label: {
			HStack {
				Text(themeName)
					.foregroundStyle(Color.primary)
				Spacer()
				if isCurrentTheme {
					Image(systemName: "checkmark")
						.foregroundStyle(.tint)
				}
			}
		}
		.accessibilityAddTraits(isCurrentTheme ? .isSelected : [])
		.swipeActions(edge: .trailing, allowsFullSwipe: false) {
			if model.deletableThemeNames.contains(themeName) {
				Button(String(localized: "Delete", comment: "Delete button"), systemImage: "trash") {
					themeNamePendingDeletion = themeName
				}
				.tint(.red)
			}
		}
	}

	func deleteThemeMessage(_ themeName: String) -> String {
		let localizedMessageText = NSLocalizedString("Are you sure you want to delete the theme “%@”?", comment: "Delete Theme Message")
		return NSString.localizedStringWithFormat(localizedMessageText as NSString, themeName) as String
	}

	func importThemeFile(_ url: URL) {
		guard url.startAccessingSecurityScopedResource() else {
			return
		}
		defer {
			url.stopAccessingSecurityScopedResource()
		}

		do {
			try importTheme(url)
		} catch {
			NotificationCenter.default.post(name: .didFailToImportThemeWithError, object: nil, userInfo: ["error": error])
		}
	}
}

// MARK: - ArticleThemesModel

/// Tracks the installed themes and the current theme, updating when they change.
@MainActor @Observable final class ArticleThemesModel {

	let defaultThemeName = ArticleTheme.defaultTheme.name
	private(set) var currentThemeName = ArticleTheme.defaultTheme.name
	private(set) var installedThemeNames = [String]()
	/// Themes that came with the app can’t be deleted.
	private(set) var deletableThemeNames = Set<String>()

	init() {
		update()

		NotificationCenter.default.addObserver(self, selector: #selector(handleCurrentArticleThemeDidChange(_:)), name: .CurrentArticleThemeDidChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleArticleThemeNamesDidChange(_:)), name: .ArticleThemeNamesDidChangeNotification, object: nil)
	}

	@objc func handleCurrentArticleThemeDidChange(_ notification: Notification) {
		update()
	}

	@objc func handleArticleThemeNamesDidChange(_ notification: Notification) {
		update()
	}
}

private extension ArticleThemesModel {

	func update() {
		let themeNames = ArticleThemesManager.shared.themeNames
		installedThemeNames = themeNames.filter { $0 != defaultThemeName }

		let themeName = ArticleThemesManager.shared.currentThemeName
		currentThemeName = installedThemeNames.contains(themeName) ? themeName : defaultThemeName

		deletableThemeNames = Set(themeNames.filter { themeName in
			guard let theme = ArticleThemesManager.shared.articleThemeWithThemeName(themeName) else {
				return false
			}
			return !theme.isAppTheme
		})
	}
}
