//
//  ShareFolderPickerController.swift
//  NetNewsWire iOS Share Extension
//
//  Created by Maurice Parker on 9/12/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import Account
import RSCore

protocol ShareFolderPickerControllerDelegate: AnyObject {
	func shareFolderPickerDidSelect(_ container: ExtensionContainer)
}

class ShareFolderPickerController: UITableViewController {

	var containers: [ExtensionContainer]?
	var selectedContainerID: ContainerIdentifier?

	weak var delegate: ShareFolderPickerControllerDelegate?
	
	override func viewDidLoad() {
		tableView.register(UINib(nibName: "ShareFolderPickerAccountCell", bundle: Bundle.main), forCellReuseIdentifier: "AccountCell")
		tableView.register(UINib(nibName: "ShareFolderPickerFolderCell", bundle: Bundle.main), forCellReuseIdentifier: "FolderCell")
		
	}
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return containers?.count ?? 0
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let container = containers?[indexPath.row]
		let cell: ShareFolderPickerCell = {
			if container is ExtensionAccount {
				return tableView.dequeueReusableCell(withIdentifier: "AccountCell", for: indexPath) as! ShareFolderPickerCell
			} else {
				return tableView.dequeueReusableCell(withIdentifier: "FolderCell", for: indexPath) as! ShareFolderPickerCell
			}
		}()
		
		if let account = container as? ExtensionAccount {
			cell.icon.image = AppAssets.image(for: account.type)
		} else {
			cell.icon.image = AppAssets.masterFolderImage.image
		}

		cell.label?.text = container?.name ?? ""

		if let containerID = container?.containerID, containerID == selectedContainerID {
			cell.accessoryType = .checkmark
		} else {
			cell.accessoryType = .none
		}
		
        return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		guard let container = containers?[indexPath.row] else { return }
		
		if let account = container as? ExtensionAccount, account.disallowFeedInRootFolder {
			tableView.selectRow(at: nil, animated: false, scrollPosition: .none)
		} else {
			let cell = tableView.cellForRow(at: indexPath)
			cell?.accessoryType = .checkmark
			delegate?.shareFolderPickerDidSelect(container)
		}
	}
	
}
