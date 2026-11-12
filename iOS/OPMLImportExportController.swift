//
//  OPMLImportExportController.swift
//  NetNewsWire-iOS
//
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import UIKit
import UniformTypeIdentifiers
import Account

/// Drives the account-picker then document-picker flow for OPML import and export.
///
/// Both the Settings screen and the File menu need this flow. They differ only in
/// how the account-picker popover is anchored, so the anchor is the one parameter.
@MainActor final class OPMLImportExportController: NSObject {

	private weak var presentingViewController: UIViewController?
	private weak var opmlAccount: Account?

	init(presentingViewController: UIViewController) {
		self.presentingViewController = presentingViewController
	}

	/// - Parameter sourceRect: where to anchor the account-picker popover, in the
	///   presenting view controller's view coordinates. Pass `nil` when there is no
	///   source view — a menu item or keyboard shortcut — to centre it.
	func importOPML(sourceRect: CGRect? = nil) {
		switch AccountManager.shared.activeAccounts.count {
		case 0:
			presentingViewController?.presentError(title: "Error", message: NSLocalizedString("You must have at least one active account.", comment: "Missing active account"))
		case 1:
			opmlAccount = AccountManager.shared.activeAccounts.first
			importOPMLDocumentPicker()
		default:
			importOPMLAccountPicker(sourceRect: sourceRect)
		}
	}

	func exportOPML(sourceRect: CGRect? = nil) {
		if AccountManager.shared.accounts.count == 1 {
			opmlAccount = AccountManager.shared.accounts.first
			exportOPMLDocumentPicker()
		} else {
			exportOPMLAccountPicker(sourceRect: sourceRect)
		}
	}

}

extension OPMLImportExportController: UIDocumentPickerDelegate {

	func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
		for url in urls {
			opmlAccount?.importOPML(url) { [weak self] result in
				switch result {
				case .success:
					break
				case .failure:
					let title = NSLocalizedString("Import Failed", comment: "Import Failed")
					let message = NSLocalizedString("We were unable to process the selected file.  Please ensure that it is a properly formatted OPML file.", comment: "Import Failed Message")
					self?.presentingViewController?.presentError(title: title, message: message)
				}
			}
		}
	}

}

private extension OPMLImportExportController {

	func popoverSourceRect(_ sourceRect: CGRect?, in view: UIView) -> CGRect {
		if let sourceRect {
			return sourceRect
		}
		return CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
	}

	func importOPMLAccountPicker(sourceRect: CGRect?) {
		guard let presentingViewController else {
			return
		}

		let title = NSLocalizedString("Choose an account to receive the imported feeds and folders", comment: "Import Account")
		let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)

		if let popoverController = alert.popoverPresentationController {
			popoverController.sourceView = presentingViewController.view
			popoverController.sourceRect = popoverSourceRect(sourceRect, in: presentingViewController.view)
		}

		for account in AccountManager.shared.sortedActiveAccounts {
			let action = UIAlertAction(title: account.nameForDisplay, style: .default) { [weak self] _ in
				self?.opmlAccount = account
				self?.importOPMLDocumentPicker()
			}
			alert.addAction(action)
		}

		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel button")
		alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel))

		presentingViewController.present(alert, animated: true)
	}

	func importOPMLDocumentPicker() {
		var contentTypes: [UTType] = []

		// Create UTType for .opml files by extension, without requiring conformance.
		// This ensures files ending in .opml can be selected no matter how OPML is registered.
		// <https://github.com/Ranchero-Software/NetNewsWire/issues/4858>
		if let opmlByExtension = UTType(filenameExtension: "opml") {
			contentTypes.append(opmlByExtension)
		}

		// Also try the registered org.opml.opml UTI if it exists
		if let registeredOPML = UTType("org.opml.opml") {
			contentTypes.append(registeredOPML)
		}

		// Include XML as a fallback
		contentTypes.append(.xml)

		let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
		documentPicker.delegate = self
		documentPicker.modalPresentationStyle = .formSheet
		presentingViewController?.present(documentPicker, animated: true)
	}

	func exportOPMLAccountPicker(sourceRect: CGRect?) {
		guard let presentingViewController else {
			return
		}

		let title = NSLocalizedString("Choose an account with the subscriptions to export", comment: "Export Account")
		let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)

		if let popoverController = alert.popoverPresentationController {
			popoverController.sourceView = presentingViewController.view
			popoverController.sourceRect = popoverSourceRect(sourceRect, in: presentingViewController.view)
		}

		for account in AccountManager.shared.sortedAccounts {
			let action = UIAlertAction(title: account.nameForDisplay, style: .default) { [weak self] _ in
				self?.opmlAccount = account
				self?.exportOPMLDocumentPicker()
			}
			alert.addAction(action)
		}

		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel button")
		alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel))

		presentingViewController.present(alert, animated: true)
	}

	func exportOPMLDocumentPicker() {
		guard let account = opmlAccount else {
			return
		}

		let accountName = account.nameForDisplay.replacingOccurrences(of: " ", with: "").trimmingCharacters(in: .whitespaces)
		let filename = "Subscriptions-\(accountName).opml"
		let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
		do {
			try account.logActivity(kind: .exportOPML, detail: filename) {
				let opmlString = OPMLExporter.OPMLString(with: account, title: filename)
				try opmlString.write(to: tempFile, atomically: true, encoding: String.Encoding.utf8)
			}
		} catch {
			presentingViewController?.presentError(title: "OPML Export Error", message: error.localizedDescription)
			return
		}

		let docPicker = UIDocumentPickerViewController(forExporting: [tempFile])
		docPicker.modalPresentationStyle = .formSheet
		presentingViewController?.present(docPicker, animated: true)
	}

}
