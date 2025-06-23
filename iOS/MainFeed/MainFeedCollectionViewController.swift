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

	var undoableCommands = [UndoableCommand]()
	weak var coordinator: SceneCoordinator!
	
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
        // Do any additional setup after loading the view.
    }
	
	override func viewWillLayoutSubviews() {
		configureCollectionView()
	}
	
	override func viewDidAppear(_ animated: Bool) {
		var config = UICollectionLayoutListConfiguration(appearance: .sidebar)
		config.separatorConfiguration.color = .tertiarySystemFill
		let layout = UICollectionViewCompositionalLayout.list(using: config)
		collectionView.setCollectionViewLayout(layout, animated: false)
		super.viewDidAppear(animated)
	}
	
	// MARK: - Collection View Configuration
	func configureCollectionView() {
		
	}

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    */

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
	
	// MARK: - Private
	
	func configure(_ cell: MainFeedCollectionViewCell, _ indexPath: IndexPath) {
		#warning("Implement cell configuration")
		
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
			cell.unreadCountLabel.text = feed.unreadCount.formatted()
		}

		//configureIcon(cell, indexPath)

		let rowsInSection = collectionView.numberOfItems(inSection: indexPath.section)
		if indexPath.row == rowsInSection - 1 {
			//cell.isSeparatorShown = false
		} else {
			//cell.isSeparatorShown = true
		}
		
	}
	
}

