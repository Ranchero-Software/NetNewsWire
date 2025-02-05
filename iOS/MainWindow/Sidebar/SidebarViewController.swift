//
//  SidebarViewController.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 2/2/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation
import UIKit

final class SidebarViewController: UICollectionViewController {

	enum Section {
		case smartFeeds
	}

	struct SidebarItem: Hashable, Identifiable {
		let id: UUID = UUID()
		let title: String
		let icon: UIImage?
	}

	typealias DataSource = UICollectionViewDiffableDataSource<Section, SidebarViewController.SidebarItem>
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
		let configuration = UICollectionLayoutListConfiguration(appearance: .sidebar)
		let layout = UICollectionViewCompositionalLayout.list(using: configuration)

		super.init(collectionViewLayout: layout)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {

		super.viewDidLoad()

		collectionView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 0, right: 0)

		title = "Feeds"
		navigationController?.navigationBar.prefersLargeTitles = true
		navigationItem.rightBarButtonItem = filterButton

		toolbar.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(toolbar)

		NSLayoutConstraint.activate([
			toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
			toolbar.heightAnchor.constraint(equalToConstant: 44)
		])

		let toolbarItems = [
			settingsButton,
			flexibleSpaceBarButtonItem,
			refreshProgressItemButton,
			flexibleSpaceBarButtonItem,
			addNewItemButton
		]
		toolbar.setItems(toolbarItems, animated: false)

		applySnapshot()
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

private extension SidebarViewController {

	private func createDataSource() -> DataSource {
		let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, SidebarItem> { (cell, indexPath, item) in
			var content = UIListContentConfiguration.cell()
			content.text = item.title
			content.image = item.icon
			cell.contentConfiguration = content
		}

		dataSource = UICollectionViewDiffableDataSource<Section, SidebarItem>(collectionView: collectionView) { (collectionView, indexPath, item) in
			return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
		}

		return dataSource
	}

	private func applySnapshot() {
		var snapshot = NSDiffableDataSourceSnapshot<Section, SidebarItem>()

		snapshot.appendSections([.smartFeeds])
		snapshot.appendItems([
			SidebarItem(title: "Today", icon: AppImage.today),
			SidebarItem(title: "All Unread", icon: AppImage.allUnread),
			SidebarItem(title: "Starred", icon: AppImage.starred)
		])

		dataSource.apply(snapshot, animatingDifferences: true)
	}
}
