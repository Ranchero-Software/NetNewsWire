//
//  RefreshIntervalViewController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/25/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class RefreshIntervalViewController: UITableViewController {

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 7
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
		
		cell.textLabel?.adjustsFontForContentSizeCategory = true
		
		let bgView = UIView()
		bgView.backgroundColor = AppAssets.netNewsWireBlueColor
		cell.selectedBackgroundView = bgView

		let userRefreshInterval = AppDefaults.refreshInterval
		
		switch indexPath.row {
		case 0:
			cell.textLabel?.text = RefreshInterval.manually.description()
			if userRefreshInterval == RefreshInterval.manually {
				cell.accessoryType = .checkmark
			} else {
				cell.accessoryType = .none
			}
		case 1:
			cell.textLabel?.text = RefreshInterval.every10Minutes.description()
			if userRefreshInterval == RefreshInterval.every10Minutes {
				cell.accessoryType = .checkmark
			} else {
				cell.accessoryType = .none
			}
		case 2:
			cell.textLabel?.text = RefreshInterval.every30Minutes.description()
			if userRefreshInterval == RefreshInterval.every30Minutes {
				cell.accessoryType = .checkmark
			} else {
				cell.accessoryType = .none
			}
		case 3:
			cell.textLabel?.text = RefreshInterval.everyHour.description()
			if userRefreshInterval == RefreshInterval.everyHour {
				cell.accessoryType = .checkmark
			} else {
				cell.accessoryType = .none
			}
		case 4:
			cell.textLabel?.text = RefreshInterval.every2Hours.description()
			if userRefreshInterval == RefreshInterval.every2Hours {
				cell.accessoryType = .checkmark
			} else {
				cell.accessoryType = .none
			}
		case 5:
			cell.textLabel?.text = RefreshInterval.every4Hours.description()
			if userRefreshInterval == RefreshInterval.every4Hours {
				cell.accessoryType = .checkmark
			} else {
				cell.accessoryType = .none
			}
		default:
			cell.textLabel?.text = RefreshInterval.every8Hours.description()
			if userRefreshInterval == RefreshInterval.every8Hours {
				cell.accessoryType = .checkmark
			} else {
				cell.accessoryType = .none
			}
		}
		
        return cell
		
    }
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		
		let refreshInterval: RefreshInterval
		
		switch indexPath.row {
		case 0:
			refreshInterval = RefreshInterval.manually
		case 1:
			refreshInterval = RefreshInterval.every10Minutes
		case 2:
			refreshInterval = RefreshInterval.every30Minutes
		case 3:
			refreshInterval = RefreshInterval.everyHour
		case 4:
			refreshInterval = RefreshInterval.every2Hours
		case 5:
			refreshInterval = RefreshInterval.every4Hours
		default:
			refreshInterval = RefreshInterval.every8Hours
		}
		
		AppDefaults.refreshInterval = refreshInterval
		self.navigationController?.popViewController(animated: true)
		
	}

}
