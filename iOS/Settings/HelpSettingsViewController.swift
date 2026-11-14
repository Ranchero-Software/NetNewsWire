//
//  HelpSettingsViewController.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 11/12/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import UIKit
import SafariServices
import SwiftUI

final class HelpSettingsViewController: UITableViewController {

	private enum Row: Int, CaseIterable {
		case help
		case forum
		case releaseNotes
		case bugTracker
		case about

		var title: String {
			switch self {
			case .help:
				return NSLocalizedString("NetNewsWire Help", comment: "NetNewsWire Help")
			case .forum:
				return NSLocalizedString("NetNewsWire Forum", comment: "NetNewsWire Forum")
			case .releaseNotes:
				return NSLocalizedString("Release Notes", comment: "Release Notes")
			case .bugTracker:
				return NSLocalizedString("Bug Tracker", comment: "Bug Tracker")
			case .about:
				return NSLocalizedString("About NetNewsWire", comment: "About NetNewsWire")
			}
		}
	}

	private static let cellIdentifier = "Cell"

	init() {
		super.init(style: .insetGrouped)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("Help", comment: "Help")
		tableView.register(VibrantTableViewCell.self, forCellReuseIdentifier: Self.cellIdentifier)
	}

	// MARK: - UITableViewDataSource

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return Row.allCases.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellIdentifier, for: indexPath)
		let row = Row.allCases[indexPath.row]
		cell.textLabel?.text = row.title
		cell.textLabel?.adjustsFontForContentSizeCategory = true
		cell.accessoryType = row == .about ? .disclosureIndicator : .none
		return cell
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		switch Row.allCases[indexPath.row] {
		case .help:
			openURL(HelpURL.helpHome.rawValue)
			tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
		case .forum:
			openURL(HelpURL.discourse.rawValue)
			tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
		case .releaseNotes:
			openURL(HelpURL.releaseNotes.rawValue)
			tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
		case .bugTracker:
			openURL(HelpURL.bugTracker.rawValue)
			tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
		case .about:
			navigationController?.pushViewController(UIHostingController(rootView: AboutView()), animated: true)
		}
	}
}

// MARK: - Private

private extension HelpSettingsViewController {

	func openURL(_ urlString: String) {
		guard let url = URL(string: urlString) else {
			return
		}

		// Open GitHub links in the GitHub app when installed.
		if let host = url.host, host == "github.com" || host.hasSuffix(".github.com") {
			UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { [weak self] openedInApp in
				if !openedInApp {
					self?.presentSafariViewController(for: url)
				}
			}
			return
		}

		presentSafariViewController(for: url)
	}

	func presentSafariViewController(for url: URL) {
		let vc = SFSafariViewController(url: url)
		vc.modalPresentationStyle = .pageSheet
		present(vc, animated: true)
	}
}
