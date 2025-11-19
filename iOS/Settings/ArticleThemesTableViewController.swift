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

	override func viewDidLoad() {
		let importBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(importTheme(_:)));
		importBarButtonItem.title = NSLocalizedString("Import Theme", comment: "Import Theme");
		navigationItem.rightBarButtonItem = importBarButtonItem

		NotificationCenter.default.addObserver(self, selector: #selector(articleThemeNamesDidChangeNotification(_:)), name: .ArticleThemeNamesDidChangeNotification, object: nil)
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
		return 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return ArticleThemesManager.shared.themeNames.count + 1
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

		let themeName: String
		if indexPath.row == 0 {
			themeName = ArticleTheme.defaultTheme.name
		} else {
			themeName = ArticleThemesManager.shared.themeNames[indexPath.row - 1]
		}

		cell.textLabel?.text = themeName
		if themeName == ArticleThemesManager.shared.currentTheme.name {
			cell.accessoryType = .checkmark
		} else {
			cell.accessoryType = .none
		}

		return cell
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		guard let cell = tableView.cellForRow(at: indexPath), let themeName = cell.textLabel?.text else { return }
		ArticleThemesManager.shared.currentThemeName = themeName
		navigationController?.popViewController(animated: true)
	}

	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		guard let cell = tableView.cellForRow(at: indexPath),
			  let themeName = cell.textLabel?.text,
			  let theme = ArticleThemesManager.shared.articleThemeWithThemeName(themeName),
			  !theme.isAppTheme	else { return nil }

		let deleteTitle = NSLocalizedString("Delete", comment: "Delete")
		let deleteAction = UIContextualAction(style: .normal, title: deleteTitle) { [weak self] (action, view, completion) in
			let title = NSLocalizedString("Delete Theme?", comment: "Delete Theme")

			let localizedMessageText = NSLocalizedString("Are you sure you want to delete the theme “%@”?.", comment: "Delete Theme Message")
			let message = NSString.localizedStringWithFormat(localizedMessageText as NSString, themeName) as String

			let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)

			let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
			let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel) { action in
				completion(true)
			}
			alertController.addAction(cancelAction)

			let deleteTitle = NSLocalizedString("Delete", comment: "Delete")
			let deleteAction = UIAlertAction(title: deleteTitle, style: .destructive) { action in
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
