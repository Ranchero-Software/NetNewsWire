//
//  AddFeedFolderPickerData.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/16/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//


import Foundation
import Account
import RSCore
import RSTree

struct AddFeedFolderPickerData {
	
	var containerNames = [String]()
	var containers = [Container]()
	
	init() {

		let treeControllerDelegate = FolderTreeControllerDelegate()
		
		let rootNode = Node(representedObject: AccountManager.shared.defaultAccount, parent: nil)
		rootNode.canHaveChildNodes = true
		let treeController = TreeController(delegate: treeControllerDelegate, rootNode: rootNode)

		treeController.rootNode.childNodes.forEach { node in
			
			guard let acctNameProvider = node.representedObject as? DisplayNameProvider else {
				return
			}
			
			let acctName = acctNameProvider.nameForDisplay
			containerNames.append(acctName)
			containers.append(node.representedObject as! Container)

			for child in node.childNodes {
				
				guard let childContainer = child.representedObject as? Container else {
					return
				}
				let childName = (childContainer as! DisplayNameProvider).nameForDisplay
				containerNames.append("\(acctName) / \(childName)")
				containers.append(childContainer)
				
			}
			
		}
		
	}

}
