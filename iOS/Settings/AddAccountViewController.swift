//
//  AddAccountViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 5/16/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

protocol AddAccountDismissDelegate: UIViewController {
	func dismiss()
}

class AddAccountViewController: UITableViewController, AddAccountDismissDelegate {

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		switch indexPath.row {
		case 0:
			let navController = UIStoryboard.settings.instantiateViewController(withIdentifier: "AddLocalAccountNavigationViewController") as! UINavigationController
			let addViewController = navController.topViewController as! AddLocalAccountViewController
			addViewController.delegate = self
			present(navController, animated: true)
		case 1:
			let navController = UIStoryboard.settings.instantiateViewController(withIdentifier: "FeedbinAccountNavigationViewController") as! UINavigationController
			let addViewController = navController.topViewController as! FeedbinAccountViewController
			addViewController.delegate = self
			present(navController, animated: true)
		default:
			break
		}
	}
	
	func dismiss() {
		navigationController?.popViewController(animated: false)
	}
	
}
