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
