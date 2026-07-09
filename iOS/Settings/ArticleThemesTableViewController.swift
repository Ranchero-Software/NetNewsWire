//
//  ArticleThemesTableViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/12/21.
//  Copyright © 2021 Ranchero Software. All rights reserved.
//

import Foundation
import UniformTypeIdentifiers
import UIKit

extension UTType {
	static var netNewsWireTheme: UTType { UTType(importedAs: "com.ranchero.netnewswire.theme") }
}

final class ArticleThemesTableViewController: UITableViewController {

	private enum Mode {
		case settings
		case picker(ArticleThemeSetting)
	}

	private enum SettingsSection: Int, CaseIterable {
		case mode
		case theme
	}

	private var mode = Mode.settings

	override func viewDidLoad() {
		super.viewDidLoad()

		let importBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(importTheme(_:)))
		importBarButtonItem.title = NSLocalizedString("Import Theme", comment: "Import Theme")
		navigationItem.rightBarButtonItem = importBarButtonItem

		NotificationCenter.default.addObserver(self, selector: #selector(articleThemeNamesDidChangeNotification(_:)), name: .ArticleThemeNamesDidChangeNotification, object: nil)

		updateTitle()
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		tableView.reloadData()
	}

	// MARK: Notifications

	@objc func articleThemeNamesDidChangeNotification(_ note: Notification) {
		tableView.reloadData()
	}

	@objc func importTheme(_ sender: Any?) {
		let docPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.netNewsWireTheme])
		docPicker.delegate = self
		docPicker.modalPresentationStyle = .formSheet
		self.present(docPicker, animated: true)
	}

	// MARK: - Table view data source

	override func numberOfSections(in tableView: UITableView) -> Int {
		switch mode {
		case .settings:
			return SettingsSection.allCases.count
		case .picker:
			return 1
		}
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		switch mode {
		case .settings:
			switch SettingsSection(rawValue: section) {
			case .mode:
				return ArticleThemeSelectionMode.allCases.count
			case .theme:
				return themeSettings.count
			default:
				return 0
			}
		case .picker:
			return ArticleThemesManager.shared.themeNames.count + 1
		}
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		switch mode {
		case .settings:
			return settingsCell(for: indexPath)
		case .picker(let setting):
			let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

			let themeName = themeName(at: indexPath)

			cell.textLabel?.text = themeName
			cell.detailTextLabel?.text = nil
			if themeName == ArticleThemesManager.shared.themeName(for: setting) {
				cell.accessoryType = .checkmark
			} else {
				cell.accessoryType = .none
			}

			return cell
		}
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		switch mode {
		case .settings:
			selectSettingsRow(at: indexPath)
		case .picker(let setting):
			let themeName = themeName(at: indexPath)
			selectTheme(themeName, for: setting)
			navigationController?.popViewController(animated: true)
		}
	}

	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		guard case .picker = mode else {
			return nil
		}

		let themeName = themeName(at: indexPath)
		guard let theme = ArticleThemesManager.shared.articleThemeWithThemeName(themeName), !theme.isAppTheme else {
			return nil
		}

		let deleteTitle = NSLocalizedString("Delete", comment: "Delete button")
		let deleteAction = UIContextualAction(style: .normal, title: deleteTitle) { [weak self] (_, _, completion) in
			let title = NSLocalizedString("Delete Theme?", comment: "Delete Theme")

			let localizedMessageText = NSLocalizedString("Are you sure you want to delete the theme “%@”?.", comment: "Delete Theme Message")
			let message = NSString.localizedStringWithFormat(localizedMessageText as NSString, themeName) as String

			let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)

			let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel button")
			let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel) { _ in
				completion(true)
			}
			alertController.addAction(cancelAction)

			let deleteTitle = NSLocalizedString("Delete", comment: "Delete button")
			let deleteAction = UIAlertAction(title: deleteTitle, style: .destructive) { _ in
				ArticleThemesManager.shared.deleteTheme(themeName: themeName)
				completion(true)
			}
			alertController.addAction(deleteAction)

			self?.present(alertController, animated: true)
		}

		deleteAction.image = Assets.Images.trash
		deleteAction.backgroundColor = UIColor.systemRed

		return UISwipeActionsConfiguration(actions: [deleteAction])
	}
}

// MARK: - Private

private extension ArticleThemesTableViewController {

	var themeSettings: [ArticleThemeSetting] {
		switch ArticleThemesManager.shared.themeSelectionMode {
		case .single:
			return [.single]
		case .appearance:
			return [.lightAppearance, .darkAppearance]
		}
	}

	func updateTitle() {
		switch mode {
		case .settings:
			title = NSLocalizedString("Theme", comment: "Theme")
		case .picker(let setting):
			title = setting.title
		}
	}

	func settingsCell(for indexPath: IndexPath) -> UITableViewCell {
		switch SettingsSection(rawValue: indexPath.section) {
		case .mode:
			let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
			let rowMode = ArticleThemeSelectionMode.allCases[indexPath.row]
			cell.textLabel?.text = rowMode.title
			cell.detailTextLabel?.text = nil
			cell.accessoryType = rowMode == ArticleThemesManager.shared.themeSelectionMode ? .checkmark : .none
			return cell
		case .theme:
			let cell = themeSettingCell()
			let setting = themeSettings[indexPath.row]
			cell.textLabel?.text = setting.title
			cell.detailTextLabel?.text = ArticleThemesManager.shared.themeName(for: setting)
			cell.accessoryType = .disclosureIndicator
			return cell
		default:
			return UITableViewCell()
		}
	}

	func themeSettingCell() -> UITableViewCell {
		if let cell = tableView.dequeueReusableCell(withIdentifier: "ThemeSettingCell") {
			return cell
		}
		return UITableViewCell(style: .value1, reuseIdentifier: "ThemeSettingCell")
	}

	func selectSettingsRow(at indexPath: IndexPath) {
		switch SettingsSection(rawValue: indexPath.section) {
		case .mode:
			ArticleThemesManager.shared.themeSelectionMode = ArticleThemeSelectionMode.allCases[indexPath.row]
			tableView.deselectRow(at: indexPath, animated: true)
			tableView.reloadData()
		case .theme:
			let controller = UIStoryboard.settings.instantiateController(ofType: ArticleThemesTableViewController.self)
			controller.mode = .picker(themeSettings[indexPath.row])
			navigationController?.pushViewController(controller, animated: true)
		default:
			break
		}
	}

	func themeName(at indexPath: IndexPath) -> String {
		if indexPath.row == 0 {
			return ArticleTheme.defaultTheme.name
		}
		return ArticleThemesManager.shared.themeNames[indexPath.row - 1]
	}

	func selectTheme(_ themeName: String, for setting: ArticleThemeSetting) {
		switch setting {
		case .single:
			ArticleThemesManager.shared.currentThemeName = themeName
		case .lightAppearance, .darkAppearance:
			ArticleThemesManager.shared.setThemeName(themeName, for: setting)
		}
	}
}

// MARK: UIDocumentPickerDelegate

extension ArticleThemesTableViewController: UIDocumentPickerDelegate {

	func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
		guard let url = urls.first else { return }

		if url.startAccessingSecurityScopedResource() {

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
}
