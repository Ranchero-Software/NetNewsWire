//
//  MasterTimelineDataSource.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 8/30/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class MasterTimelineDataSource<SectionIdentifierType, ItemIdentifierType>: UITableViewDiffableDataSource<SectionIdentifierType, ItemIdentifierType> where SectionIdentifierType : Hashable, ItemIdentifierType : Hashable {
	
	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		return true
	}
	
}

