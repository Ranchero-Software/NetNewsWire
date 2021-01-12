//
//  ExtensionPointInspectorViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/16/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit

class ExtensionPointInspectorViewController: UITableViewController {

	@IBOutlet weak var extensionDescription: UILabel!
	var extensionPoint: ExtensionPoint?
	
    override func viewDidLoad() {
        super.viewDidLoad()
		guard let extensionPoint = extensionPoint else { return }
		navigationItem.title = extensionPoint.title
		extensionDescription.attributedText = extensionPoint.description
		tableView.register(ImageHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
	}
	
	@IBAction func disable(_ sender: Any) {
		guard let extensionPoint = extensionPoint else { return	}
		
		let title = NSLocalizedString("Deactivate Extension", comment: "Deactivate Extension")
		let extensionPointTypeTitle = extensionPoint.extensionPointID.extensionPointType.title
		let message = NSLocalizedString("Are you sure you want to deactivate the \(extensionPointTypeTitle) extension “\(extensionPoint.title)”?", comment: "Deactivate text")

		let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
		let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel)
		alertController.addAction(cancelAction)
		
		let markTitle = NSLocalizedString("Deactivate", comment: "Deactivate")
		let markAction = UIAlertAction(title: markTitle, style: .default) { [weak self] (action) in
			ExtensionPointManager.shared.deactivateExtensionPoint(extensionPoint.extensionPointID)
			self?.navigationController?.popViewController(animated: true)
		}
		alertController.addAction(markAction)
		alertController.preferredAction = markAction
		
		present(alertController, animated: true)
		
	}
}

// MARK: Table View

extension ExtensionPointInspectorViewController {
	
	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return section == 0 ? ImageHeaderView.rowHeight : super.tableView(tableView, heightForHeaderInSection: section)
	}
	
	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		guard let extensionPoint = extensionPoint else { return nil }

		if section == 0 {
			let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SectionHeader") as! ImageHeaderView
			headerView.imageView.image = extensionPoint.image
			return headerView
		} else {
			return super.tableView(tableView, viewForHeaderInSection: section)
		}
	}

	override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
		if indexPath.section > 0 {
			return true
		}
		return false
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
	}
	
}

