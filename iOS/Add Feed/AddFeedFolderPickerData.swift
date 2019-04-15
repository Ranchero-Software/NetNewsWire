//Copyright © 2019 Vincode, Inc. All rights reserved.

import Foundation
import Account
import RSCore
import RSTree

struct AddFeedFolderPickerData {
	
	var containerNames = [String]()
	var containers = [Container]()
	
	init() {

		let treeControllerDelegate = FolderTreeControllerDelegate()
		
		let rootNode = Node(representedObject: AccountManager.shared.localAccount, parent: nil)
		rootNode.canHaveChildNodes = true
		let treeController = TreeController(delegate: treeControllerDelegate, rootNode: rootNode)

		guard let rootNameProvider = treeController.rootNode.representedObject as? DisplayNameProvider else {
			return
		}
		
		let rootName = rootNameProvider.nameForDisplay
		containerNames.append(rootName)
		containers.append(treeController.rootNode.representedObject as! Container)
		
		treeController.rootNode.childNodes.forEach { node in
			guard let childContainer = node.representedObject as? Container else {
				return
			}
			let childName = (childContainer as! DisplayNameProvider).nameForDisplay
			containerNames.append("\(rootName) / \(childName)")
			containers.append(childContainer)
		}
		
	}

}
