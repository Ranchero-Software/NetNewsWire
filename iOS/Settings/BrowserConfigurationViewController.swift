//
//  BrowserConfigurationViewController.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 22/8/21.
//  Copyright © 2021 Ranchero Software. All rights reserved.
//

import UIKit

class BrowserConfigurationViewController: UITableViewController {

	let browserManager = BrowserManager.shared
	
    override func viewDidLoad() {
        super.viewDidLoad()
		title = NSLocalizedString("Browser Selection", comment: "Browser")
		NotificationCenter.default.addObserver(self, selector: #selector(browserPreferenceDidChange), name: .browserPreferenceDidChange, object: nil)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if section == 0 { return 1 }
		if section == 1 { return 1 }
		return browserManager.availableBrowsers.count - 2
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		if indexPath.section == 0 {
			let cell = tableView.dequeueReusableCell(withIdentifier: "BrowserCell", for: indexPath) as! BrowserCell
			cell.configure(with: browserManager.availableBrowsers[indexPath.row])
			return cell
		}
		
		if indexPath.section == 1 {
			let cell = tableView.dequeueReusableCell(withIdentifier: "BrowserCell", for: indexPath) as! BrowserCell
			cell.configure(with: browserManager.availableBrowsers[indexPath.row + 1])
			return cell
		}
		
		if indexPath.section == 2 {
			let cell = tableView.dequeueReusableCell(withIdentifier: "BrowserCell", for: indexPath) as! BrowserCell
			cell.configure(with: browserManager.availableBrowsers[indexPath.row + 2])
			return cell
		}
		
		return tableView.dequeueReusableCell(withIdentifier: "BrowserCell") ?? UITableViewCell()
    }

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		guard let cell = tableView.cellForRow(at: indexPath) as? BrowserCell else {
			return
		}
		cell.updateBrowserSelection()
		navigationController?.popViewController(animated: true)
	}
	
	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		if section == 0 {
			return NSLocalizedString("Open Links In", comment: "Open Links")
		}
		return nil
	}
	
	override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		if section == 0 {
			return NSLocalizedString("Links will open in NetNewsWire.", comment: "NNW browser footer.")
		}
		
		if section == 1 {
			return NSLocalizedString("Links will open in the default system browser configured in Settings.", comment: "Default browser footer.")
		}
		
		
		return nil
	}
	
	// MARK: - Notifications
	@objc func browserPreferenceDidChange() {
		tableView.reloadData()
	}

}
