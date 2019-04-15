//
//  MasterSecondaryViewController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import Account
import RSCore
import RSTree

class MasterSecondaryViewController: MasterViewController {

	var viewRootNode: Node?
	
	// MARK: - Table View
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return viewRootNode?.numberOfChildNodes ?? 0
	}
	
	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		
		if editingStyle == .delete {
			
			guard let containerNode = viewRootNode,
				let deleteNode = containerNode.childAtIndex(indexPath.row),
				let container = containerNode.representedObject as? Container,
				let feed = deleteNode.representedObject as? Feed else {
					return
			}
			
			animatingChanges = true
			container.deleteFeed(feed)
			treeController.rebuild()
			tableView.deleteRows(at: [indexPath], with: .fade)
			animatingChanges = false
			
		} else if editingStyle == .insert {
			// Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
		}
		
	}

	// MARK: API
	
	override func delete(indexPath: IndexPath) {

		guard let containerNode = viewRootNode,
			let deleteNode = containerNode.childAtIndex(indexPath.row),
			let container = containerNode.representedObject as? Container,
			let feed = deleteNode.representedObject as? Feed else {
				return
		}
		
		animatingChanges = true
		container.deleteFeed(feed)
		treeController.rebuild()
		tableView.deleteRows(at: [indexPath], with: .fade)
		animatingChanges = false

	}
	
	override func nodeFor(indexPath: IndexPath) -> Node? {
		return viewRootNode?.childAtIndex(indexPath.row)
	}

}
