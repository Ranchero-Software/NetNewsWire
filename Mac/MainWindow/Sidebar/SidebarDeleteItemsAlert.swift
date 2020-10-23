//
//  SidebarDeleteItemsAlert.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 10/23/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import AppKit
import RSTree
import Account

enum SidebarDeleteItemsAlert {
	
	/// Builds a delete confirmation dialog for the supplied nodes
	static func build(_ nodes: [Node]) -> NSAlert {
		let alert = NSAlert()
		alert.alertStyle = .warning
		
		if nodes.count == 1 {
			if let folder = nodes.first?.representedObject as? Folder {
				alert.messageText = NSLocalizedString("Delete Folder", comment: "Delete Folder")
				let localizedInformativeText = NSLocalizedString("Are you sure you want to delete the “%@” folder?", comment: "Folder delete text")
				alert.informativeText = NSString.localizedStringWithFormat(localizedInformativeText as NSString, folder.nameForDisplay) as String
			} else if let feed = nodes.first?.representedObject as? Feed {
				alert.messageText = NSLocalizedString("Delete Feed", comment: "Delete Feed")
				let localizedInformativeText = NSLocalizedString("Are you sure you want to delete the “%@” feed?", comment: "Feed delete text")
				alert.informativeText = NSString.localizedStringWithFormat(localizedInformativeText as NSString, feed.nameForDisplay) as String
			}
		} else {
			alert.messageText = NSLocalizedString("Delete Items", comment: "Delete Items")
			let localizedInformativeText = NSLocalizedString("Are you sure you want to delete the %d selected items?", comment: "Items delete text")
			alert.informativeText = NSString.localizedStringWithFormat(localizedInformativeText as NSString, nodes.count) as String
		}
		
		alert.addButton(withTitle: NSLocalizedString("Delete", comment: "Delete Account"))
		alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel Delete Account"))
			
		return alert
	}
	
}
