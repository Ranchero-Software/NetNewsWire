//
//  ArticleThemesTableViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/12/21.
//  Copyright © 2021 Ranchero Software. All rights reserved.
//

import Foundation

import UIKit

class ArticleThemesTableViewController: UITableViewController {

	// MARK: - Table view data source

	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return ArticleThemesManager.shared.themeNames.count + 1
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
		
		let themeName: String
		if indexPath.row == 0 {
			themeName = ArticleTheme.defaultTheme.name
		} else {
			themeName = ArticleThemesManager.shared.themeNames[indexPath.row - 1]
		}
		
		cell.textLabel?.text = themeName
		if themeName == ArticleThemesManager.shared.currentTheme.name {
			cell.accessoryType = .checkmark
		} else {
			cell.accessoryType = .none
		}
		
		return cell
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		guard let cell = tableView.cellForRow(at: indexPath), let themeName = cell.textLabel?.text else { return }
		ArticleThemesManager.shared.currentThemeName = themeName
		navigationController?.popViewController(animated: true)
	}

}
