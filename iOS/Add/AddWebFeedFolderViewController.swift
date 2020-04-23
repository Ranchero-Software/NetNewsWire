//
//  AddWebFeedFolderViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/16/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore
import Account

protocol AddWebFeedFolderViewControllerDelegate {
	func didSelect(container: Container)
}

class AddWebFeedFolderViewController: UITableViewController {
	
	var delegate: AddWebFeedFolderViewControllerDelegate?
	var initialContainer: Container?
	
	var containers = [Container]()

    override func viewDidLoad() {
        super.viewDidLoad()
		
		for account in AccountManager.shared.sortedActiveAccounts {
			containers.append(account)
			if let sortedFolders = account.sortedFolders {
				containers.append(contentsOf: sortedFolders)
			}
		}
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return containers.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let container = containers[indexPath.row]
		let cell: AddComboTableViewCell = {
			if container is Account {
				return tableView.dequeueReusableCell(withIdentifier: "AccountCell", for: indexPath) as! AddComboTableViewCell
			} else {
				return tableView.dequeueReusableCell(withIdentifier: "FolderCell", for: indexPath) as! AddComboTableViewCell
			}
		}()
		
		if let smallIconProvider = container as? SmallIconProvider {
			cell.icon?.image = smallIconProvider.smallIcon?.image
		}
		
		if let displayNameProvider = container as? DisplayNameProvider {
			cell.label?.text = displayNameProvider.nameForDisplay
		}
		
		if let compContainer = initialContainer, container === compContainer {
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
			delegate?.didSelect(container: container)
			dismiss()
		}
	}
	
	// MARK: Actions
	
	@IBAction func cancel(_ sender: Any) {
		dismiss()
	}
	
}

private extension AddWebFeedFolderViewController {
	
	func dismiss() {
		dismiss(animated: true)
	}
	
}
