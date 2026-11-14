//
//  ArticlesSettingsViewController.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 11/17/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import UIKit
import UniformTypeIdentifiers

final class ArticlesSettingsViewController: UITableViewController {

	private enum Section: Int, CaseIterable {
		case themes
		case behavior
	}

	fileprivate enum Row {
		case theme
		case importTheme
		case deleteTheme
		case openLinksInNetNewsWire
		case enableJavaScript
		case swipeToNextPreviousArticle
		case enableFullScreenArticles
	}

	private let openLinksInNetNewsWireSwitch = UISwitch()
	private let enableJavaScriptSwitch = UISwitch()
	private let swipeToNextPreviousArticleSwitch = UISwitch()
	private let enableFullScreenArticlesSwitch = UISwitch()

	private let themeCell = VibrantTableViewCell(style: .default, reuseIdentifier: nil)
	private let themePopUpButton = UIButton.makeSettingsPopUpButton()
	private let importThemeCell = UITableViewCell(style: .default, reuseIdentifier: nil)
	private let deleteThemeCell = UITableViewCell(style: .default, reuseIdentifier: nil)

	private var rows = [Section: [Row]]()
	private var cells = [Row: UITableViewCell]()

	init() {
		super.init(style: .insetGrouped)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("Articles", comment: "Articles")

		rows[.themes] = [.theme, .importTheme, .deleteTheme]
		// The Full Screen Articles row is iPhone-only.
		rows[.behavior] = [.openLinksInNetNewsWire, .enableJavaScript, .swipeToNextPreviousArticle, .enableFullScreenArticles].filter { $0 != .enableFullScreenArticles || traitCollection.userInterfaceIdiom == .phone }

		NotificationCenter.default.addObserver(self, selector: #selector(handleCurrentArticleThemeDidChange(_:)), name: .CurrentArticleThemeDidChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleArticleThemeNamesDidChange(_:)), name: .ArticleThemeNamesDidChangeNotification, object: nil)

		themeCell.selectionStyle = .none
		themeCell.textLabel?.text = NSLocalizedString("Theme", comment: "Theme")
		themeCell.textLabel?.numberOfLines = 0
		themeCell.textLabel?.adjustsFontForContentSizeCategory = true
		themeCell.addSettingsPopUpButton(themePopUpButton, accessibilityLabel: NSLocalizedString("Theme", comment: "Theme"))
		updateThemePopUpButton()

		configureButtonCell(importThemeCell, title: NSLocalizedString("Import Theme…", comment: "Import Theme…"))
		importThemeCell.textLabel?.textColor = Assets.Colors.primaryAccent

		configureButtonCell(deleteThemeCell, title: NSLocalizedString("Delete Theme…", comment: "Delete Theme…"))
		updateDeleteThemeCell()

		cells[.theme] = themeCell
		cells[.importTheme] = importThemeCell
		cells[.deleteTheme] = deleteThemeCell
		cells[.openLinksInNetNewsWire] = makeCell(switch: openLinksInNetNewsWireSwitch,
												  title: NSLocalizedString("Open Links in NetNewsWire", comment: "Open Links in NetNewsWire"),
												  footnote: nil,
												  action: #selector(switchOpenLinksInNetNewsWire(_:)))
		cells[.enableJavaScript] = makeCell(switch: enableJavaScriptSwitch,
											title: NSLocalizedString("Enable JavaScript", comment: "Enable JavaScript"),
											footnote: NSLocalizedString("Some content, such as videos and embedded social media posts, may require JavaScript to work correctly.", comment: "Some content, such as videos and embedded social media posts, may require JavaScript to work correctly."),
											action: #selector(switchEnableJavaScript(_:)))
		cells[.swipeToNextPreviousArticle] = makeCell(switch: swipeToNextPreviousArticleSwitch,
													  title: NSLocalizedString("Enable Horizontal Swipe to Previous and Next Article", comment: "Enable Horizontal Swipe to Previous and Next Article"),
													  footnote: nil,
													  action: #selector(switchSwipeToNextPreviousArticle(_:)))
		cells[.enableFullScreenArticles] = makeCell(switch: enableFullScreenArticlesSwitch,
													title: NSLocalizedString("Enable Full Screen Articles", comment: "Enable Full Screen Articles"),
													footnote: NSLocalizedString("Tap the article top bar to enter Full Screen. Tap the top or bottom to exit.", comment: "Tap the article top bar to enter Full Screen. Tap the top or bottom to exit."),
													action: #selector(switchEnableFullScreenArticles(_:)))
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		openLinksInNetNewsWireSwitch.isOn = !AppDefaults.useSystemBrowser
		enableJavaScriptSwitch.isOn = AppDefaults.isArticleContentJavascriptEnabled
		swipeToNextPreviousArticleSwitch.isOn = AppDefaults.articleSwipeNavigationEnabled
		enableFullScreenArticlesSwitch.isOn = AppDefaults.articleFullscreenAvailable
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
	}

	// MARK: - UITableViewDataSource

	override func numberOfSections(in tableView: UITableView) -> Int {
		Section.allCases.count
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		switch Section(rawValue: section) {
		case .themes:
			NSLocalizedString("Themes", comment: "Themes")
		case .behavior:
			NSLocalizedString("Behavior", comment: "Behavior")
		case nil:
			nil
		}
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		rowsInSection(section).count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		cells[rowsInSection(indexPath.section)[indexPath.row]] ?? UITableViewCell()
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.selectRow(at: nil, animated: true, scrollPosition: .none)

		switch rowsInSection(indexPath.section)[indexPath.row] {
		case .importTheme:
			presentImportThemePicker()
		case .deleteTheme:
			presentDeleteThemeChoices()
		default:
			break
		}
	}

	// MARK: - Actions

	@objc func switchOpenLinksInNetNewsWire(_ sender: UISwitch) {
		AppDefaults.useSystemBrowser = !sender.isOn
	}

	@objc func switchEnableJavaScript(_ sender: UISwitch) {
		AppDefaults.isArticleContentJavascriptEnabled = sender.isOn
	}

	@objc func switchSwipeToNextPreviousArticle(_ sender: UISwitch) {
		AppDefaults.articleSwipeNavigationEnabled = sender.isOn
	}

	@objc func switchEnableFullScreenArticles(_ sender: UISwitch) {
		AppDefaults.articleFullscreenAvailable = sender.isOn
	}

	// MARK: - Notifications

	@objc func handleCurrentArticleThemeDidChange(_ notification: Notification) {
		updateThemePopUpButton()
	}

	@objc func handleArticleThemeNamesDidChange(_ notification: Notification) {
		updateThemePopUpButton()
		updateDeleteThemeCell()
	}
}

// MARK: - UIDocumentPickerDelegate

extension ArticlesSettingsViewController: UIDocumentPickerDelegate {

	func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
		guard let url = urls.first else {
			return
		}
		guard url.startAccessingSecurityScopedResource() else {
			return
		}
		defer {
			url.stopAccessingSecurityScopedResource()
		}

		do {
			try ArticleThemeImporter.importTheme(controller: self, url: url)
		} catch {
			NotificationCenter.default.post(name: .didFailToImportThemeWithError, object: nil, userInfo: ["error": error])
		}
	}
}

// MARK: - Private

private extension ArticlesSettingsViewController {

	func rowsInSection(_ section: Int) -> [Row] {
		guard let section = Section(rawValue: section) else {
			return []
		}
		return rows[section] ?? []
	}

	func updateThemePopUpButton() {
		let defaultThemeName = ArticleTheme.defaultTheme.name
		let installedThemeNames = ArticleThemesManager.shared.themeNames.filter { $0 != defaultThemeName }
		var currentThemeName = ArticleThemesManager.shared.currentThemeName
		if !installedThemeNames.contains(currentThemeName) {
			currentThemeName = defaultThemeName
		}

		func themeAction(_ themeName: String) -> UIAction {
			UIAction(title: themeName, state: themeName == currentThemeName ? .on : .off) { _ in
				ArticleThemesManager.shared.currentThemeName = themeName
			}
		}

		let defaultThemeMenu = UIMenu(options: .displayInline, children: [themeAction(defaultThemeName)])
		let installedThemesMenu = UIMenu(options: .displayInline, children: installedThemeNames.map { themeAction($0) })
		themePopUpButton.menu = UIMenu(children: [defaultThemeMenu, installedThemesMenu])
		themePopUpButton.accessibilityValue = currentThemeName
	}

	/// Themes that came with the app can’t be deleted.
	var deletableThemeNames: [String] {
		ArticleThemesManager.shared.themeNames.filter { themeName in
			guard let theme = ArticleThemesManager.shared.articleThemeWithThemeName(themeName) else {
				return false
			}
			return !theme.isAppTheme
		}
	}

	func updateDeleteThemeCell() {
		let isEnabled = !deletableThemeNames.isEmpty
		deleteThemeCell.isUserInteractionEnabled = isEnabled
		deleteThemeCell.textLabel?.isEnabled = isEnabled
		deleteThemeCell.textLabel?.textColor = isEnabled ? .systemRed : .tertiaryLabel
		deleteThemeCell.accessibilityTraits = isEnabled ? .button : [.button, .notEnabled]
	}

	func presentImportThemePicker() {
		let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.netNewsWireTheme])
		documentPicker.delegate = self
		documentPicker.modalPresentationStyle = .formSheet
		present(documentPicker, animated: true)
	}

	func presentDeleteThemeChoices() {
		let themeNames = deletableThemeNames
		guard !themeNames.isEmpty else {
			return
		}

		let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
		for themeName in themeNames {
			alertController.addAction(UIAlertAction(title: themeName, style: .destructive) { [weak self] _ in
				self?.confirmDeleteTheme(themeName)
			})
		}
		alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel button"), style: .cancel))

		if let popoverController = alertController.popoverPresentationController {
			popoverController.sourceView = deleteThemeCell
			popoverController.sourceRect = deleteThemeCell.bounds
		}
		present(alertController, animated: true)
	}

	func confirmDeleteTheme(_ themeName: String) {
		let title = NSLocalizedString("Delete Theme?", comment: "Delete Theme")
		let localizedMessageText = NSLocalizedString("Are you sure you want to delete the theme “%@”?", comment: "Delete Theme Message")
		let message = NSString.localizedStringWithFormat(localizedMessageText as NSString, themeName) as String

		let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
		alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel button"), style: .cancel))
		alertController.addAction(UIAlertAction(title: NSLocalizedString("Delete", comment: "Delete button"), style: .destructive) { _ in
			ArticleThemesManager.shared.deleteTheme(themeName: themeName)
		})
		present(alertController, animated: true)
	}

	func configureButtonCell(_ cell: UITableViewCell, title: String) {
		cell.textLabel?.text = title
		cell.textLabel?.numberOfLines = 0
		cell.textLabel?.adjustsFontForContentSizeCategory = true
		cell.accessibilityTraits = .button
	}

	/// A plain cell, rather than a vibrant one, so the footnote keeps its secondary color.
	func makeCell(switch toggle: UISwitch, title: String, footnote: String?, action: Selector) -> UITableViewCell {
		let cell = UITableViewCell(style: footnote == nil ? .default : .subtitle, reuseIdentifier: nil)
		cell.selectionStyle = .none
		cell.textLabel?.text = title
		cell.textLabel?.numberOfLines = 0
		cell.textLabel?.adjustsFontForContentSizeCategory = true
		if let footnote {
			cell.detailTextLabel?.text = footnote
			cell.detailTextLabel?.numberOfLines = 0
			cell.detailTextLabel?.font = .preferredFont(forTextStyle: .footnote)
			cell.detailTextLabel?.textColor = .secondaryLabel
			cell.detailTextLabel?.adjustsFontForContentSizeCategory = true
		}
		toggle.onTintColor = Assets.Colors.primaryAccent
		toggle.addTarget(self, action: action, for: .valueChanged)
		cell.accessoryView = toggle
		return cell
	}
}
