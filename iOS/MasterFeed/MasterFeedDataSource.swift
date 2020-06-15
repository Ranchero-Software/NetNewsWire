//
//  MasterFeedDataSource.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 8/28/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import RSTree
import Account

class MasterFeedDataSource: UITableViewDiffableDataSource<Int, MasterFeedTableViewIdentifier> {

	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		guard let identifier = itemIdentifier(for: indexPath), identifier.isEditable else {
			return false
		}
		return true
	}
	
}
