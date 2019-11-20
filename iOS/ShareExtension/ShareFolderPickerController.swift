//
//  ShareFolderPickerController.swift
//  NetNewsWire iOS Share Extension
//
//  Created by Maurice Parker on 9/12/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore
import Account

protocol ShareFolderPickerControllerDelegate: class {
	func shareFolderPickerDidSelect(_ container: Container)
}

class ShareFolderPickerController: UITableViewController {

	var selectedContainer: Container?
	var containers = [Container]()

	weak var delegate: ShareFolderPickerControllerDelegate?
	
	override func viewDidLoad() {
		for account in AccountManager.shared.sortedActiveAccounts {
			containers.append(account)
			if let sortedFolders = account.sortedFolders {
				containers.append(contentsOf: sortedFolders)
			}
		}

		tableView.register(UINib(nibName: "ShareFolderPickerAccountCell", bundle: Bundle.main), forCellReuseIdentifier: "AccountCell")
		tableView.register(UINib(nibName: "ShareFolderPickerFolderCell", bundle: Bundle.main), forCellReuseIdentifier: "FolderCell")
	}
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return containers.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let container = containers[indexPath.row]
		let cell: ShareFolderPickerCell = {
			if container is Account {
				return tableView.dequeueReusableCell(withIdentifier: "AccountCell", for: indexPath) as! ShareFolderPickerCell
			} else {
				return tableView.dequeueReusableCell(withIdentifier: "FolderCell", for: indexPath) as! ShareFolderPickerCell
			}
		}()
		
		if let account = container as? Account {
			cell.icon.image = AppAssets.image(for: account.type)
		} else {
			cell.icon.image = AppAssets.masterFolderImage.image
		}
		
		if let displayNameProvider = container as? DisplayNameProvider {
			cell.label?.text = displayNameProvider.nameForDisplay
		}
		
		if let compContainer = selectedContainer, container === compContainer {
			cell.accessoryType = .checkmark
		} else {
			cell.accessoryType = .none
		}
		
        return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let container = containers[indexPath.row]
		
		if let account = container as? Account, account.behaviors.contains(.disallowFeedInRootFolder) {
			tableView.selectRow(at: nil, animated: false, scrollPosition: .none)
		} else {
			let cell = tableView.cellForRow(at: indexPath)
			cell?.accessoryType = .checkmark
			delegate?.shareFolderPickerDidSelect(container)
		}
	}
	
}
