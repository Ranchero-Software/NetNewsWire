//
//  ShareFolderPickerController.swift
//  NetNewsWire iOS Share Extension
//
//  Created by Maurice Parker on 9/12/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import Account

protocol ShareFolderPickerControllerDelegate: class {
	func shareFolderPickerDidSelect(_ container: Container, _ selectionName: String)
}

class ShareFolderPickerController: UITableViewController {

	var pickerData: FlattenedAccountFolderPickerData?
	var selectedContainer: Container?
	
	weak var delegate: ShareFolderPickerControllerDelegate?
	
	override func viewDidLoad() {
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
	}
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return pickerData?.containerNames.count ?? 0
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
		cell.textLabel?.text = pickerData?.containerNames[indexPath.row] ?? ""
		if pickerData?.containers[indexPath.row] === selectedContainer {
			cell.accessoryType = .checkmark
		} else {
			cell.accessoryType = .none
		}
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		guard let pickerData = pickerData else { return }
		delegate?.shareFolderPickerDidSelect(pickerData.containers[indexPath.row], pickerData.containerNames[indexPath.row])
	}
	
}
