//
//  AddAccountViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 5/16/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Account
import UIKit

protocol AddAccountDismissDelegate: UIViewController {
	func dismiss()
}

class AddAccountViewController: UITableViewController, AddAccountDismissDelegate {

	@IBOutlet private weak var localAccountNameLabel: UILabel!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		localAccountNameLabel.text = Account.defaultLocalAccountName
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let storyboard = UIStoryboard.settings
		switch indexPath.row {
		case 0:
			let addViewController = storyboard.instantiateViewController(withIdentifier: "AddLocalAccountViewController") as! AddLocalAccountViewController
			addViewController.delegate = self
			navigationController?.pushViewController(addViewController, animated: true)
		case 1:
			let addViewController = storyboard.instantiateViewController(withIdentifier: "FeedbinAccountViewController") as! FeedbinAccountViewController
			addViewController.delegate = self
			navigationController?.pushViewController(addViewController, animated: true)
		default:
			break
		}
	}
	
	func dismiss() {
		navigationController?.popToRootViewController(animated: true)
	}
	
}
