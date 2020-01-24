//
//  SourceListOrderingViewController.swift
//  NetNewsWire-iOS
//
//  Created by Louis-Jean Teitelbaum on 24/01/2020.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit

class SourceListOrderingViewController: UITableViewController {
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = super.tableView(tableView, cellForRowAt: indexPath)
		
		switch (indexPath.row, AppDefaults.sourceListOrdering) {
		case (0, .alphabetically),
			 (1, .foldersFirst),
			 (2, .topLevelFeedsFirst):
			cell.accessoryType = .checkmark
		default:
			cell.accessoryType = .none
		}
		return cell
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		switch indexPath.row {
		case 0:
			AppDefaults.sourceListOrdering = .alphabetically
		case 1:
			AppDefaults.sourceListOrdering = .foldersFirst
		case 2:
			AppDefaults.sourceListOrdering = .topLevelFeedsFirst
		default:
			break
		}
		tableView.visibleCells.forEach { $0.accessoryType = .none }
		tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
		tableView.deselectRow(at: indexPath, animated: true)
		
		NotificationCenter.default.post(name: .SourceListOrderingDidChange, object: self, userInfo: nil)
	}
}
