//
//  TimelineNumberOfLinesViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/29/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class TimelineNumberOfLinesViewController: UITableViewController {

	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 5
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		
		let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
		
		cell.textLabel?.adjustsFontForContentSizeCategory = true
		
		let bgView = UIView()
		bgView.backgroundColor = AppAssets.netNewsWireBlueColor
		cell.selectedBackgroundView = bgView
		
		cell.textLabel?.text = "\(2 + indexPath.row)" + NSLocalizedString(" lines", comment: "Lines")

		let numberOfLines = AppDefaults.timelineNumberOfLines
		if indexPath.row + 2 == numberOfLines {
			cell.accessoryType = .checkmark
		} else {
			cell.accessoryType = .none
		}
		
		return cell
		
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		AppDefaults.timelineNumberOfLines = indexPath.row + 2
		self.navigationController?.popViewController(animated: true)
	}

}
