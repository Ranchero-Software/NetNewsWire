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

	init() {
		super.init(collectionViewLayout: Self.createSidebarLayout())
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {

		super.viewDidLoad()

		applySnapshot()
	}
}

private extension SidebarViewController {

	static func createSidebarLayout() -> UICollectionViewLayout {
		let configuration = UICollectionLayoutListConfiguration(appearance: .sidebar)
		return UICollectionViewCompositionalLayout.list(using: configuration)
	}

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
