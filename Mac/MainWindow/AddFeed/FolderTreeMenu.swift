//
//  FolderTreeMenu.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 9/12/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import RSCore
import RSTree
import Account

class FolderTreeMenu {

	static func createFolderPopupMenu(with rootNode: Node) -> NSMenu {
		
		let menu = NSMenu(title: "Folders")
		
		for childNode in rootNode.childNodes {
			
			guard let nameProvider = childNode.representedObject as? DisplayNameProvider else {
				continue
			}
			
			let menuItem = NSMenuItem(title: nameProvider.nameForDisplay, action: nil, keyEquivalent: "")
			menuItem.representedObject = childNode.representedObject
			menu.addItem(menuItem)

			let childNodes = childNode.childNodes
			addFolderItemsToMenuWithNodes(menu: menu, nodes: childNodes, indentationLevel: 1)
			
		}
		
		return menu
	}

	static func select(account: Account, folder: Folder?, in popupButton: NSPopUpButton) {
		for menuItem in popupButton.itemArray {
			if let oneAccount = menuItem.representedObject as? Account, oneAccount == account && folder == nil {
				popupButton.select(menuItem)
				return
			}
			if let oneFolder = menuItem.representedObject as? Folder, oneFolder == folder {
				if oneFolder.account == account {
					popupButton.select(menuItem)
					return
				}
			}
		}
	}

	private static func addFolderItemsToMenuWithNodes(menu: NSMenu, nodes: [Node], indentationLevel: Int) {
		
		nodes.forEach { (oneNode) in
			
			if let nameProvider = oneNode.representedObject as? DisplayNameProvider {
				
				let menuItem = NSMenuItem(title: nameProvider.nameForDisplay, action: nil, keyEquivalent: "")
				menuItem.indentationLevel = indentationLevel
				menuItem.representedObject = oneNode.representedObject
				menu.addItem(menuItem)
				
				if oneNode.numberOfChildNodes > 0 {
					addFolderItemsToMenuWithNodes(menu: menu, nodes: oneNode.childNodes, indentationLevel: indentationLevel + 1)
				}
			}
		}
	}
	
}
