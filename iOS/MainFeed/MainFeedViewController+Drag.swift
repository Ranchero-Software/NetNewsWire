//
//  MainFeedViewController+Drag.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/20/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import MobileCoreServices
import Account
import UniformTypeIdentifiers

extension MainFeedViewController: UITableViewDragDelegate {
	
	func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
		guard let node = coordinator.nodeFor(indexPath), let webFeed = node.representedObject as? WebFeed else {
			return [UIDragItem]()
		}
		
		let data = webFeed.url.data(using: .utf8)
		let itemProvider = NSItemProvider()
		  
		itemProvider.registerDataRepresentation(forTypeIdentifier: UTType.url.identifier, visibility: .ownProcess) { completion in
			completion(data, nil)
			return nil
		}
		
		let dragItem = UIDragItem(itemProvider: itemProvider)
		dragItem.localObject = node
		return [dragItem]
	}
	
}
