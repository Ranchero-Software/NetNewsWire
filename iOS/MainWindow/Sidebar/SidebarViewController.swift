////
////  SidebarViewController.swift
////  NetNewsWire-iOS
////
////  Created by Brent Simmons on 2/2/25.
////  Copyright © 2025 Ranchero Software. All rights reserved.
////
//
//import Foundation
//import UIKit
//import Account
//
//final class SidebarViewController: UICollectionViewController {
//
//	typealias DataSource = UICollectionViewDiffableDataSource<SectionID, SidebarItemID>
//	private lazy var dataSource = createDataSource()
//
//	private lazy var filterButton = UIBarButtonItem(
//		image: AppImage.filterInactive,
//		style: .plain,
//		target: self,
//		action: #selector(toggleFilter(_:))
//	)
//
//	private lazy var settingsButton = UIBarButtonItem(
//		image: AppImage.settings,
//		style: .plain,
//		target: self,
//		action: #selector(showSettings(_:))
//	)
//
//	private lazy var addNewItemButton = UIBarButtonItem(systemItem: .add)
//
//	private lazy var refreshProgressItemButton = UIBarButtonItem(customView: refreshProgressView)
//	private lazy var refreshProgressView: RefreshProgressView = Bundle.main.loadNibNamed("RefreshProgressView", owner: self, options: nil)?[0] as! RefreshProgressView
//
//	private lazy var flexibleSpaceBarButtonItem = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
//
//	private lazy var toolbar = UIToolbar()
//
//	init() {
//		var configuration = UICollectionLayoutListConfiguration(appearance: .sidebar)
//		configuration.headerMode = .supplementary
//		let layout = UICollectionViewCompositionalLayout.list(using: configuration)
//
//		super.init(collectionViewLayout: layout)
//	}
//
//	required init?(coder: NSCoder) {
//		fatalError("init(coder:) has not been implemented")
//	}
//
//	override func viewDidLoad() {
//
//		super.viewDidLoad()
//
//		collectionView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 0, right: 0)
//
//		title = "Feeds"
//		navigationController?.navigationBar.prefersLargeTitles = true
//		navigationItem.rightBarButtonItem = filterButton
//
//		toolbar.translatesAutoresizingMaskIntoConstraints = false
//		view.addSubview(toolbar)
//
//		NSLayoutConstraint.activate([
//			toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//			toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//			toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
//			toolbar.heightAnchor.constraint(equalToConstant: 44)
//		])
//
//		let toolbarItems = [
//			settingsButton,
//			flexibleSpaceBarButtonItem,
//			refreshProgressItemButton,
//			flexibleSpaceBarButtonItem,
//			addNewItemButton
//		]
//		toolbar.setItems(toolbarItems, animated: false)
//
//		collectionView.register(SidebarHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: SidebarHeaderView.reuseIdentifier)
//
//		applySnapshot()
//	}
//}
//
//// MARK: - Actions
//
//// TODO: Implement actions
//
//extension SidebarViewController {
//
//	@objc func toggleFilter(_ sender: Any) {
//	}
//
//	@objc func showSettings(_ sender: Any?) {
//	}
//}
//
//// MARK: - SidebarHeaderViewDelegate
//
//extension SidebarViewController: SidebarHeaderViewDelegate {
//
//	func sidebarHeaderViewUserDidToggleExpanded(_ sidebarHeaderView: SidebarHeaderView) {
//		var section = sections[sidebarHeaderView.sectionIndex]
//		section.isExpanded.toggle()
//		applySnapshot()
//	}
//}
//
//private extension SidebarViewController {
//
//	func createDataSource() -> DataSource {
//		let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, SidebarItem> { (cell, _, item) in
//			var content = UIListContentConfiguration.cell()
//			content.text = item.title
//			content.image = item.icon
//			cell.contentConfiguration = content
//		}
//
//		dataSource = UICollectionViewDiffableDataSource<Section, SidebarItem>(collectionView: collectionView) { (collectionView, indexPath, item) in
//			return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
//		}
//
//		let headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionHeader) { header, _, indexPath in
//
//			let section = self.dataSource.snapshot().sectionIdentifiers[indexPath.section]
//
//			var content = UIListContentConfiguration.sidebarHeader()
//			content.text = sectionTitle(for: section)
//			header.contentConfiguration = content
//
//			// Add a disclosure indicator to show collapsible behavior
//			let button = UIButton(type: .system)
//			button.setImage(UIImage(systemName: "chevron.down"), for: .normal)
//			button.tintColor = .secondaryLabel
//			button.addTarget(self, action: #selector(self.toggleSection(_:)), for: .touchUpInside)
//			button.tag = indexPath.section
//			header.accessories = [.customView(configuration: .init(customView: button, placement: .trailing(displayed: .always)))]
//
//			// Rotate chevron based on section state
//			button.transform = sectionStates[section] == true ? .identity : CGAffineTransform(rotationAngle: -.pi / 2)
//		}
//
//		dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
//			let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: SidebarHeaderView.reuseIdentifier, for: indexPath) as! SidebarHeaderView
//			let section = self.sections[indexPath.section]
//			header.configure(title: section.title, sectionIndex: indexPath.section, delegate: self)
//			return header
//		}
//
//		return dataSource
//	}
//
//	func applySnapshot() {
//		var snapshot = NSDiffableDataSourceSnapshot<Section, SidebarItem>()
//
//		for section in sections {
//			snapshot.appendSections([section])
//			if section.isExpanded {
//				snapshot.appendItems(section.items, toSection: section)
//			}
//		}
//
//		dataSource.apply(snapshot, animatingDifferences: true)
//	}
//}
//
//protocol SidebarHeaderViewDelegate: AnyObject {
//
//	func sidebarHeaderViewUserDidToggleExpanded(_: SidebarHeaderView)
//}
//
//final class SidebarHeaderView: UICollectionReusableView {
//
//	static let reuseIdentifier = "SidebarHeaderView"
//
//	var sectionIndex: Int = 0
//	var delegate: SidebarHeaderViewDelegate?
//
//	override init(frame: CGRect) {
//		super.init(frame: frame)
//		backgroundColor = .darkGray
//
//		let tapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleExpanded(_:)))
//		addGestureRecognizer(tapGesture)
//	}
//
//	required init?(coder: NSCoder) {
//		fatalError("init(coder:) has not been implemented")
//	}
//
//	func configure(title: String, sectionIndex: Int, delegate: SidebarHeaderViewDelegate) {
//		self.sectionIndex = sectionIndex
//		self.delegate = delegate
//
//		let label = UILabel(frame: bounds)
//		label.text = title
//		label.textColor = .white
//		label.textAlignment = .center
//		addSubview(label)
//	}
//
//	@objc func toggleExpanded(_ sender: Any?) {
//		delegate?.sidebarHeaderViewUserDidToggleExpanded(self)
////		guard let controller else {
////			return
////		}
////		controller.sections[sectionIndex].state.toggle()
////		controller.applySnapshot()
//	}
//}
