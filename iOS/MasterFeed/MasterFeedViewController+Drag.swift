//
//  MasterFeedViewController+Drag.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/20/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import MobileCoreServices
import Account

extension MasterFeedViewController: UITableViewDragDelegate {
	
	func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
		guard let identifier = dataSource.itemIdentifier(for: indexPath), identifier.isWebFeed, let url = identifier.url else {
			return [UIDragItem]()
		}
		
		let data = url.data(using: .utf8)
		let itemProvider = NSItemProvider()
		  
		itemProvider.registerDataRepresentation(forTypeIdentifier: kUTTypeURL as String, visibility: .ownProcess) { completion in
			completion(data, nil)
			return nil
		}
		
		let dragItem = UIDragItem(itemProvider: itemProvider)
		dragItem.localObject = identifier
		return [dragItem]
	}
	
}
