//
//  MasterFeedDataSource.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 8/28/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore
import RSTree
import Account

class MasterFeedDataSource: UITableViewDiffableDataSource<Node, Node> {

	private var coordinator: SceneCoordinator!
	
	init(coordinator: SceneCoordinator, tableView: UITableView, cellProvider: @escaping UITableViewDiffableDataSource<Node, Node>.CellProvider) {
		super.init(tableView: tableView, cellProvider: cellProvider)
		self.coordinator = coordinator
		self.defaultRowAnimation = .middle
	}
	
	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		guard let node = itemIdentifier(for: indexPath), !(node.representedObject is PseudoFeed) else {
			return false
		}
		return true
	}
	
}
