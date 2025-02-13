//
//  SidebarViewController.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 2/2/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation
import UIKit
import Account

protocol SidebarViewControllerDelegate: AnyObject {

	func sidebarViewController(_: SidebarViewController, didSelect: [any Item])
}

final class SidebarViewController: UICollectionViewController {

	weak var delegate: SidebarViewControllerDelegate?
	
	private let tree = SidebarTree()

	typealias DataSource = UICollectionViewDiffableDataSource<SectionID, ItemID>
	private lazy var dataSource = createDataSource()

	private lazy var filterButton = UIBarButtonItem(
		image: AppImage.filterInactive,
		style: .plain,
		target: self,
		action: #selector(toggleFilter(_:))
	)

	private lazy var settingsButton = UIBarButtonItem(
		image: AppImage.settings,
		style: .plain,
		target: self,
		action: #selector(showSettings(_:))
	)

	private lazy var addNewItemButton = UIBarButtonItem(systemItem: .add)

	private lazy var refreshProgressItemButton = UIBarButtonItem(customView: refreshProgressView)
	private lazy var refreshProgressView: RefreshProgressView = Bundle.main.loadNibNamed("RefreshProgressView", owner: self, options: nil)?[0] as! RefreshProgressView

	private lazy var flexibleSpaceBarButtonItem = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

	private lazy var toolbar = UIToolbar()

	init() {
		var configuration = UICollectionLayoutListConfiguration(appearance: .sidebar)
		configuration.headerMode = .supplementary
		let layout = UICollectionViewCompositionalLayout.list(using: configuration)

		super.init(collectionViewLayout: layout)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {

		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(feedIconDidBecomeAvailable(_:)), name: .feedIconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(feedSettingDidChange(_:)), name: .feedSettingDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange(_:)), name: .DisplayNameDidChange, object: nil)

		super.viewDidLoad()

		title = "Feeds"
		navigationController?.navigationBar.prefersLargeTitles = true
		navigationController?.navigationBar.tintColor = .white
		navigationController?.navigationBar.isTranslucent = false

		if let subviews = navigationController?.navigationBar.subviews {
			for subview in subviews {
				if subview.frame.height < 2 {
					subview.isHidden = true
				}
			}
		}

		navigationItem.rightBarButtonItem = filterButton
		navigationItem.largeTitleDisplayMode = .always
		
		toolbar.barTintColor = AppColor.toolbarBackground
		toolbar.tintColor = .white
		toolbar.isTranslucent = false
		toolbar.translatesAutoresizingMaskIntoConstraints = false

		view.addSubview(toolbar)

		NSLayoutConstraint.activate([
			toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
		])

		let toolbarItems = [
			settingsButton,
			flexibleSpaceBarButtonItem,
			refreshProgressItemButton,
			flexibleSpaceBarButtonItem,
			addNewItemButton
		]
		toolbar.setItems(toolbarItems, animated: false)

		tree.rebuild()
		applySnapshot()
	}

	override func viewDidLayoutSubviews() {

		super.viewDidLayoutSubviews()

		// Make collection view aware of toolbar — so that bottom isn’t trapped under the toolbar.
		let toolbarHeight = toolbar.frame.height
		collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: toolbarHeight, right: 0)
		collectionView.verticalScrollIndicatorInsets.bottom = toolbarHeight
	}

	override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

		guard let itemID = dataSource.itemIdentifier(for: indexPath) else {
			assertionFailure("Expected itemID for indexPath \(indexPath).")
			return
		}
		guard let item = tree.item(with: itemID) else {
			assertionFailure("Expected item for itemID \(itemID).")
			return
		}

		delegate?.sidebarViewController(self, didSelect: [item])
	}
}

// MARK: - Actions

// TODO: Implement actions

extension SidebarViewController {

	@objc func toggleFilter(_ sender: Any) {
	}

	@objc func showSettings(_ sender: Any?) {
	}
}

// MARK: - Notifications

private extension SidebarViewController {

	@objc func faviconDidBecomeAvailable(_ note: Notification) {
		updateVisibleRows()
	}

	@objc func feedIconDidBecomeAvailable(_ note: Notification) {
		updateVisibleRows()
	}

	@objc func feedSettingDidChange(_ note: Notification) {
		updateVisibleRows()
	}

	@objc func displayNameDidChange(_ note: Notification) {
		updateVisibleRows()
	}
}

// MARK: - Private

private extension SidebarViewController {

	static let imageSize = CGSize(width: 24, height: 24)

	func createDataSource() -> DataSource {

		let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, ItemID> { cell, _, itemID in

			guard let item = self.tree.item(with: itemID) else {
				preconditionFailure("Expected item \(itemID) to exist in sidebar tree.")
			}

			var config = UIListContentConfiguration.cell()
			config.text = item.title

			// TODO: different configuration for SF Symbols?
			//config.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)

			config.image = item.image
			config.imageProperties.cornerRadius = 6
			config.imageProperties.reservedLayoutSize = Self.imageSize
			config.imageProperties.maximumSize = Self.imageSize
//			config.imageProperties.tintColor = .secondaryLabel

			cell.contentConfiguration = config
		}

		let dataSource = DataSource(collectionView: collectionView) { collectionView, indexPath, itemID in
			return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: itemID)
		}

		let headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionHeader) { header, _, indexPath in

			let sectionID = self.dataSource.snapshot().sectionIdentifiers[indexPath.section]
			guard let section = self.tree.section(with: sectionID) else {
				preconditionFailure("Expected sectionID and section for indexPath \(indexPath) to exist in sidebar tree.")
			}

			var content = UIListContentConfiguration.header()
			content.text = section.title
			header.contentConfiguration = content

			// Add a disclosure indicator to show collapsible behavior
			let button = UIButton(type: .system)
			button.setImage(UIImage(systemName: "chevron.down"), for: .normal)
			button.tintColor = .secondaryLabel
			//			button.addTarget(self, action: #selector(self.toggleSection(_:)), for: .touchUpInside)
			button.tag = indexPath.section
			header.accessories = [.customView(configuration: .init(customView: button, placement: .trailing(displayed: .always)))]

			// Rotate chevron based on section state
			button.transform = section.isExpanded ? .identity : CGAffineTransform(rotationAngle: -.pi / 2)
		}

		dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
			collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
		}

		return dataSource
	}

	func applySnapshot() {

		var snapshot = NSDiffableDataSourceSnapshot<SectionID, ItemID>()

		for section in tree.sections {
			let sectionID = section.id
			snapshot.appendSections([sectionID])

			if section.isExpanded {
				let itemIDs = section.items.map { $0.id }
				snapshot.appendItems(itemIDs, toSection: sectionID)

				// TODO: handle folders
			}
		}

		dataSource.apply(snapshot, animatingDifferences: true)
	}

	func updateVisibleRows() {

		var itemIDsToReload = [ItemID]()

		for indexPath in collectionView.indexPathsForVisibleItems {
			if let itemID = dataSource.itemIdentifier(for: indexPath) {
				itemIDsToReload.append(itemID)
			}
		}

		if !itemIDsToReload.isEmpty {
			var snapshot = dataSource.snapshot()
			snapshot.reloadItems(itemIDsToReload)
			dataSource.apply(snapshot, animatingDifferences: false)
		}
	}
}
