//
//  MasterPrimaryViewController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import Account
import RSCore
import RSTree

class MasterPrimaryViewController: MasterViewController {

	// MARK: Actions
	
	@IBAction func showOPMLImportExport(_ sender: UIBarButtonItem) {
		
		let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
		
		let importOPML = UIAlertAction(title: "Import OPML", style: .default) { [unowned self] alertAction in
			let docPicker = UIDocumentPickerViewController(documentTypes: ["public.xml", "org.opml.opml"], in: .import)
			docPicker.delegate = self
			docPicker.modalPresentationStyle = .formSheet
			self.present(docPicker, animated: true)
		}
		optionMenu.addAction(importOPML)
		
		let exportOPML = UIAlertAction(title: "Export OPML", style: .default) { [unowned self] alertAction in
			
			let filename = "MySubscriptions.opml"
			let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
			let opmlString = OPMLExporter.OPMLString(with: AccountManager.shared.localAccount, title: filename)
			do {
				try opmlString.write(to: tempFile, atomically: true, encoding: String.Encoding.utf8)
			} catch {
				self.presentError(title: "OPML Export Error", message: error.localizedDescription)
			}
			
			let docPicker = UIDocumentPickerViewController(url: tempFile, in: .exportToService)
			docPicker.modalPresentationStyle = .formSheet
			self.present(docPicker, animated: true)
			
		}
		optionMenu.addAction(exportOPML)
		optionMenu.addAction(UIAlertAction(title: "Cancel", style: .cancel))
		
		if let popoverController = optionMenu.popoverPresentationController {
			popoverController.barButtonItem = sender
		}

		self.present(optionMenu, animated: true)
		
	}
	
	// MARK: - Table View
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return treeController.rootNode.numberOfChildNodes
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return treeController.rootNode.childAtIndex(section)?.numberOfChildNodes ?? 0
	}
	
	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		guard let nameProvider = treeController.rootNode.childAtIndex(section)?.representedObject as? DisplayNameProvider else {
			return nil
		}
		return nameProvider.nameForDisplay
	}
	
	// MARK: API
	
	override func delete(indexPath: IndexPath) {
		
		guard let containerNode = treeController.rootNode.childAtIndex(indexPath.section),
			let deleteNode = containerNode.childAtIndex(indexPath.row),
			let container = containerNode.representedObject as? Container else {
				return
		}
		
		animatingChanges = true
		
		if let feed = deleteNode.representedObject as? Feed {
			container.deleteFeed(feed)
		}
		
		if let folder = deleteNode.representedObject as? Folder {
			container.deleteFolder(folder)
		}
		
		treeController.rebuild()
		tableView.deleteRows(at: [indexPath], with: .automatic)
		
		animatingChanges = false
		
	}
	
	override func nodeFor(indexPath: IndexPath) -> Node? {
		return treeController.rootNode.childAtIndex(indexPath.section)?.childAtIndex(indexPath.row)
	}
	
}

extension MasterPrimaryViewController: UIDocumentPickerDelegate {
	
	func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
		
		for url in urls {
			do {
				try OPMLImporter.parseAndImport(fileURL: url, account: AccountManager.shared.localAccount)
			} catch {
				presentError(title: "OPML Import Error", message: error.localizedDescription)
			}
		}
		
	}
	
}
