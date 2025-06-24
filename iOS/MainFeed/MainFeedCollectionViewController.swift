//
//  MainFeedCollectionViewController.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 23/06/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import UIKit
import WebKit
import Account
import Articles
import RSCore
import RSTree
import RSWeb
import SafariServices

private let reuseIdentifier = "FeedCell"

class MainFeedCollectionViewController: UICollectionViewController, UndoableCommandRunner {

	@IBOutlet weak var filterButton: UIBarButtonItem!
	@IBOutlet weak var addNewItemButton: UIBarButtonItem! {
		didSet {
			addNewItemButton.primaryAction = nil
		}
	}
	
	
	var undoableCommands = [UndoableCommand]()
	weak var coordinator: SceneCoordinator!
	
	
	override func viewDidLoad() {
		super.viewDidLoad()
		registerForNotifications()
        // Do any additional setup after loading the view.
    }
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		navigationController?.isToolbarHidden = false
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		configureCollectionView()
		self.navigationController?.navigationBar.prefersLargeTitles = true
	}
	
	func registerForNotifications() {
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
		// TODO: fix this temporary hack, which will probably require refactoring image handling.
		// We want to know when to possibly reconfigure our cells with a new image, and we don’t
		// always know when an image is available — but watching the .htmlMetadataAvailable Notification
		// lets us know that it’s time to request an image.
		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .htmlMetadataAvailable, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(webFeedIconDidBecomeAvailable(_:)), name: .feedIconDidBecomeAvailable, object: nil)
	}
	
	// MARK: - Collection View Configuration
	func configureCollectionView() {
		var config = UICollectionLayoutListConfiguration(appearance: UIDevice.current.userInterfaceIdiom == .pad ? .sidebar : .insetGrouped)
		config.separatorConfiguration.color = .tertiarySystemFill
		config.headerMode = .supplementary
		let layout = UICollectionViewCompositionalLayout.list(using: config)
		collectionView.setCollectionViewLayout(layout, animated: false)
	}

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    */
	
	@IBAction func settings(_ sender: UIBarButtonItem) {
		coordinator.showSettings()
	}

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        // #warning Incomplete implementation, return the number of sections
		return coordinator.numberOfSections()
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of items
		return coordinator.numberOfRows(in: section)
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as? MainFeedCollectionViewCell
		configure(cell!, indexPath)
    
        return cell!
    }
	
	override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		coordinator.selectFeed(indexPath: indexPath, animations: [.navigation, .select, .scroll])
	}

    // MARK: UICollectionViewDelegate

    /*
    // Uncomment this method to specify if the specified item should be highlighted during tracking
    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
    override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
    
    }
    */

	
	// MARK: - API
	
	func focus() {
		becomeFirstResponder()
	}
	
	func updateUI() {
		#warning("Implement updateUI()")
		
//		if coordinator.isReadFeedsFiltered {
//			setFilterButtonToActive()
//		} else {
//			setFilterButtonToInactive()
//		}
//		addNewItemButton?.isEnabled = !AccountManager.shared.activeAccounts.isEmpty
//
//		configureContextMenu()
	}
	
	
	func updateFeedSelection(animations: Animations) {
		#warning("Implement updateFeedSelection()")
		
//		if let indexPath = coordinator.currentFeedIndexPath {
//			tableView.selectRowAndScrollIfNotVisible(at: indexPath, animations: animations)
//		} else {
//			if let indexPath = tableView.indexPathForSelectedRow {
//				if animations.contains(.select) {
//					tableView.deselectRow(at: indexPath, animated: true)
//				} else {
//					tableView.deselectRow(at: indexPath, animated: false)
//				}
//			}
//		}
	}
	
	func openInAppBrowser() {
		if let indexPath = coordinator.currentFeedIndexPath,
			let url = coordinator.homePageURLForFeed(indexPath) {
			let vc = SFSafariViewController(url: url)
			vc.modalPresentationStyle = .overFullScreen
			present(vc, animated: true)
		}
	}
	
	func reloadFeeds(initialLoad: Bool, changes: ShadowTableChanges, completion: (() -> Void)? = nil) {
		updateUI()

		guard !initialLoad else {
			collectionView.reloadData()
			completion?()
			return
		}
		
		collectionView.performBatchUpdates {
			if let deletes = changes.deletes, !deletes.isEmpty {
				collectionView.deleteSections(IndexSet(deletes))
			}
			
			if let inserts = changes.inserts, !inserts.isEmpty {
				collectionView.insertSections(IndexSet(inserts))
			}
			
			if let moves = changes.moves, !moves.isEmpty {
				for move in moves {
					collectionView.moveSection(move.from, toSection: move.to)
				}
			}

			if let rowChanges = changes.rowChanges {
				for rowChange in rowChanges {
					if let deletes = rowChange.deleteIndexPaths, !deletes.isEmpty {
						collectionView.deleteItems(at: deletes)
					}
					
					if let inserts = rowChange.insertIndexPaths, !inserts.isEmpty {
						collectionView.insertItems(at: inserts)
					}
					
					if let moves = rowChange.moveIndexPaths, !moves.isEmpty {
						for move in moves {
							collectionView.moveItem(at: move.0, to: move.1)
						}
					}
				}
			}
		}
		
		if let rowChanges = changes.rowChanges {
			for rowChange in rowChanges {
				if let reloads = rowChange.reloadIndexPaths, !reloads.isEmpty {
					collectionView.reloadItems(at: reloads)
				}
			}
		}

		completion?()
	}
	
	func applyToAvailableCells(_ completion: (MainFeedCollectionViewCell, IndexPath) -> Void) {
		collectionView.visibleCells.forEach { cell in
			guard let indexPath = collectionView.indexPath(for: cell) else { return }
			completion(cell as! MainFeedCollectionViewCell, indexPath)
		}
	}
	
	func configureIcon(_ cell: MainFeedCollectionViewCell, _ indexPath: IndexPath) {
		guard let node = coordinator.nodeFor(indexPath), let feed = node.representedObject as? Feed, let feedID = feed.feedID else {
			return
		}
		cell.faviconView.iconImage = IconImageCache.shared.imageFor(feedID)
	}
	
	func configureCellsForRepresentedObject(_ representedObject: AnyObject) {
		applyToCellsForRepresentedObject(representedObject, configure)
	}

	func applyToCellsForRepresentedObject(_ representedObject: AnyObject, _ completion: (MainFeedCollectionViewCell, IndexPath) -> Void) {
		applyToAvailableCells { (cell, indexPath) in
			if let node = coordinator.nodeFor(indexPath),
			   let representedFeed = representedObject as? Feed,
			   let candidate = node.representedObject as? Feed,
			   representedFeed.feedID == candidate.feedID {
				completion(cell, indexPath)
			}
		}
	}
	
	// MARK: - Private
	
	func configure(_ cell: MainFeedCollectionViewCell, _ indexPath: IndexPath) {
		#warning("Implement cell configuration")
		if UIDevice.current.userInterfaceIdiom == .pad {
			cell.contentView.backgroundColor = .clear
		}
		guard let node = coordinator.nodeFor(indexPath) else { return }

		//cell.delegate = self
		if node.representedObject is Folder {
			//cell.indentationLevel = 0
		} else {
			//cell.indentationLevel = 1
		}
		
		if let containerID = (node.representedObject as? Container)?.containerID {
			//cell.setDisclosure(isExpanded: coordinator.isExpanded(containerID), animated: false)
			//cell.isDisclosureAvailable = true
		} else {
			//cell.isDisclosureAvailable = false
		}
		
		if let feed = node.representedObject as? Feed {
			cell.feedTitle.text = feed.nameForDisplay
			cell.unreadCount = feed.unreadCount
			
			if UIDevice.current.userInterfaceIdiom == .pad {
				let isSelected = collectionView.indexPathsForSelectedItems?.contains(indexPath) ?? false
				cell.feedTitle.textColor = isSelected ? .systemBlue : .label
			}
		}

		configureIcon(cell, indexPath)

		let rowsInSection = collectionView.numberOfItems(inSection: indexPath.section)
		if indexPath.row == rowsInSection - 1 {
			//cell.isSeparatorShown = false
		} else {
			//cell.isSeparatorShown = true
		}
		
	}
	
	
	// MARK: - Notifications
	
	@objc func unreadCountDidChange(_ note: Notification) {
		updateUI()

		guard let unreadCountProvider = note.object as? UnreadCountProvider else {
			return
		}
		
		if let account = unreadCountProvider as? Account {
			#warning("Implement headerview logic")
//			if let headerView = headerViewForAccount(account) {
//				headerView.unreadCount = account.unreadCount
//			}
			return
		}

		var node: Node? = nil
		if let coordinator = unreadCountProvider as? SceneCoordinator, let feed = coordinator.timelineFeed {
			node = coordinator.rootNode.descendantNodeRepresentingObject(feed as AnyObject)
		} else {
			node = coordinator.rootNode.descendantNodeRepresentingObject(unreadCountProvider as AnyObject)
		}

		guard let unreadCountNode = node, let indexPath = coordinator.indexPathFor(unreadCountNode) else { return }
		
		if let cell = collectionView.cellForItem(at: indexPath) as? MainFeedCollectionViewCell {
			cell.unreadCount = unreadCountProvider.unreadCount
		}
	}
	
	@objc func faviconDidBecomeAvailable(_ note: Notification) {
		applyToAvailableCells(configureIcon)
	}

	@objc func webFeedIconDidBecomeAvailable(_ note: Notification) {
		guard let webFeed = note.userInfo?[UserInfoKey.webFeed] as? WebFeed else {
			return
		}
		applyToCellsForRepresentedObject(webFeed, configureIcon(_:_:))
	}
	
}

