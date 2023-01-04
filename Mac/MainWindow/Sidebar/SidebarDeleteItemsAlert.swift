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
				alert.messageText = NSLocalizedString("alert.title.delete-folder", comment: "Delete Folder")
				let localizedInformativeText = NSLocalizedString("alert.message.delete-folder.%@", comment: "Are you sure you want to delete the “%@” folder?")
				alert.informativeText = NSString.localizedStringWithFormat(localizedInformativeText as NSString, folder.nameForDisplay) as String
			} else if let feed = nodes.first?.representedObject as? Feed {
				alert.messageText = NSLocalizedString("alert.title.delete-feed", comment: "Delete Feed")
				let localizedInformativeText = NSLocalizedString("alert.message.delete-feed.%@", comment: "Are you sure you want to delete the “%@” feed?")
				alert.informativeText = NSString.localizedStringWithFormat(localizedInformativeText as NSString, feed.nameForDisplay) as String
			}
		} else {
			alert.messageText = NSLocalizedString("alert.title.delete-items", comment: "Delete Items")
			let localizedInformativeText = NSLocalizedString("alert.message.delete-items.%d", comment: "Are you sure you want to delete the %d selected items?")
			alert.informativeText = NSString.localizedStringWithFormat(localizedInformativeText as NSString, nodes.count) as String
		}
		
		alert.addButton(withTitle: NSLocalizedString("button.title.delete", comment: "Delete Account"))
		alert.addButton(withTitle: NSLocalizedString("button.title.cancel", comment: "Cancel Delete Account"))
			
		return alert
	}
	
}
