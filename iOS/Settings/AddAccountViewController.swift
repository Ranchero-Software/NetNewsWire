//
//  AddAccountViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 5/16/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Account
import UIKit

class AddAccountViewController: UITableViewController {

	@IBOutlet private weak var localAccountNameLabel: UILabel!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		localAccountNameLabel.text = Account.defaultLocalAccountName
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		switch indexPath.row {
		case 0:
			let viewController = UIStoryboard.settings.instantiateViewController(withIdentifier: "AddLocalAccountNavigationViewController")
			present(viewController, animated: true)
		default:
			break
		}
	}
	
}
