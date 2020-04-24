//
//  AddExtensionViewContrller.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/16/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit

protocol AddExtensionDismissDelegate: UIViewController {
	func dismiss()
}

class AddExtensionViewController: UITableViewController, AddExtensionDismissDelegate {

	private var availableExtensionPointTypes = [ExtensionPoint.Type]()

	override func viewDidLoad() {
		super.viewDidLoad()
		availableExtensionPointTypes = ExtensionPointManager.shared.availableExtensionPointTypes
	}

	override func numberOfSections(in tableView: UITableView) -> Int {
		1
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return availableExtensionPointTypes.count
	}
	
	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return 52.0
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsExtensionTableViewCell", for: indexPath) as! SettingsComboTableViewCell
		
		let extensionPointType = availableExtensionPointTypes[indexPath.row]
		cell.comboNameLabel?.text = extensionPointType.title
		cell.comboImage?.image =  extensionPointType.templateImage
		
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let navController = UIStoryboard.settings.instantiateViewController(withIdentifier: "EnableExtensiontNavigationViewController") as! UINavigationController
		navController.modalPresentationStyle = .currentContext
		let enableViewController = navController.topViewController as! EnableExtensionViewController
		enableViewController.delegate = self
		enableViewController.extensionPointType = availableExtensionPointTypes[indexPath.row]
		present(navController, animated: true)
	}
	
	func dismiss() {
		navigationController?.popViewController(animated: false)
	}
	
}
