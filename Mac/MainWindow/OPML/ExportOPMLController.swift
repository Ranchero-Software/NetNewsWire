//
//  ExportOPMLController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/1/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Account

class ExportOPMLController: ExportOPMLAccessoryViewControllerDelegate {

	weak var savePanel: NSSavePanel?

	func runSheetOnWindow(_ hostWindow: NSWindow) {

		let accessoryViewController = ExportOPMLAccessoryViewController(delegate: self)
		let panel = NSSavePanel()
		panel.allowedFileTypes = ["opml"]
		panel.allowsOtherFileTypes = false
		panel.prompt = NSLocalizedString("Export OPML", comment: "Export OPML")
		panel.title = NSLocalizedString("Export OPML", comment: "Export OPML")
		panel.nameFieldLabel = NSLocalizedString("Export to:", comment: "Export OPML")
		panel.message = NSLocalizedString("Choose a location for the exported OPML file.", comment: "Export OPML")
		panel.isExtensionHidden = false
		panel.accessoryView = accessoryViewController.view

		updateNameFieldStringValueIfAppropriate(savePanel: panel, from: accessoryViewController, force: true)

		savePanel = panel
		
		panel.beginSheetModal(for: hostWindow) { result in
			if result == NSApplication.ModalResponse.OK, let url = panel.url {
				DispatchQueue.main.async {
					guard let account = accessoryViewController.selectedAccount else { return }
					let filename = url.lastPathComponent
					let opmlString = OPMLExporter.OPMLString(with: account, title: filename)
					do {
						try opmlString.write(to: url, atomically: true, encoding: .utf8)
					}
					catch let error as NSError {
						NSApplication.shared.presentError(error)
					}
				}
			}
		}
		
	}

	private func updateNameFieldStringValueIfAppropriate(savePanel panel: NSSavePanel, from accessoryViewController: ExportOPMLAccessoryViewController, force: Bool = false) {

		if !force && !panel.nameFieldStringValue.hasPrefix("Subscriptions-") { return }

		guard let account = accessoryViewController.selectedAccount else { return }
		let accountName = account.nameForDisplay.replacingOccurrences(of: " ", with: "").trimmingCharacters(in: .whitespaces)
		panel.nameFieldStringValue = "Subscriptions-\(accountName).opml"

	}

	internal func selectedAccountDidChange(_ accessoryViewController: ExportOPMLAccessoryViewController) {
		if let savePanel = savePanel {
			self.updateNameFieldStringValueIfAppropriate(savePanel: savePanel, from: accessoryViewController)
		}
	}
}
