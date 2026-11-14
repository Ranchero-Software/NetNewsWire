//
//  TroubleshootingSettingsViewController.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 11/12/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import UIKit
import SwiftUI
import Account

final class TroubleshootingSettingsViewController: UITableViewController {

	private enum Row: CaseIterable {
		case errorLog
		case activityLog
		case accountStats
		case dinosaurs
		case cloudKitZoneStats

		var title: String {
			switch self {
			case .errorLog:
				return NSLocalizedString("Error Log", comment: "Error Log window title")
			case .activityLog:
				return NSLocalizedString("Activity Log", comment: "Activity Log screen title")
			case .accountStats:
				return NSLocalizedString("Account Stats", comment: "Account Stats screen title")
			case .dinosaurs:
				return NSLocalizedString("Dinosaurs", comment: "Dinosaurs")
			case .cloudKitZoneStats:
				return NSLocalizedString("iCloud Storage Stats", comment: "iCloud Storage Stats window title")
			}
		}
	}

	private static let cellIdentifier = "Cell"

	weak var presentingParentController: UIViewController?

	private var rows = [Row]()

	init() {
		super.init(style: .insetGrouped)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("Troubleshooting", comment: "Troubleshooting")
		tableView.register(VibrantTableViewCell.self, forCellReuseIdentifier: Self.cellIdentifier)

		// iCloud Storage Stats is shown only when there’s an iCloud account.
		rows = Row.allCases.filter { $0 != .cloudKitZoneStats || AccountManager.shared.hasiCloudAccount }
	}

	// MARK: - UITableViewDataSource

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return rows.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellIdentifier, for: indexPath)
		cell.textLabel?.text = rows[indexPath.row].title
		cell.textLabel?.adjustsFontForContentSizeCategory = true
		cell.accessoryType = .disclosureIndicator
		return cell
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let viewController: UIViewController = {
			switch rows[indexPath.row] {
			case .errorLog:
				return UIHostingController(rootView: ErrorLogView())
			case .activityLog:
				return UIHostingController(rootView: ActivityLogView())
			case .accountStats:
				return UIHostingController(rootView: AccountStatsView())
			case .cloudKitZoneStats:
				return UIHostingController(rootView: CloudKitStatsView())
			case .dinosaurs:
				return UIHostingController(rootView: DinosaursView(dismissAndPresent: { [weak self] dinosaur in
					guard let self else {
						return
					}
					self.dismiss(animated: true) {
						if let rootSplit = self.presentingParentController as? RootSplitViewController {
							rootSplit.coordinator.discloseFeed(dinosaur.feed, animations: [.scroll, .navigation])
						}
					}
				}))
			}
		}()
		navigationController?.pushViewController(viewController, animated: true)
	}
}
