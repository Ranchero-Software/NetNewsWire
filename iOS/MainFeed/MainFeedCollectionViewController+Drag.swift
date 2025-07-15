//
//  MainFeedCollectionViewController+Drag.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 14/07/2025.
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
import UniformTypeIdentifiers

extension MainFeedCollectionViewController: UICollectionViewDragDelegate {
	func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: any UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
		guard let node = coordinator.nodeFor(indexPath), let webFeed = node.representedObject as? WebFeed else {
			return [UIDragItem]()
		}
		
		let data = webFeed.url.data(using: .utf8)
		let itemProvider = NSItemProvider()
		  
		itemProvider.registerDataRepresentation(forTypeIdentifier: UTType.url.identifier, visibility: .ownProcess) { completion in
			completion(data, nil)
			return nil
		}
		
		let dragItem = UIDragItem(itemProvider: itemProvider)
		dragItem.localObject = node
		return [dragItem]
	}
	
	func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
		let parameters = UIDragPreviewParameters()
		if UIDevice.current.userInterfaceIdiom == .pad, let cell = collectionView.cellForItem(at: indexPath) {
			let bounds = cell.bounds
			let capsulePath = UIBezierPath(roundedRect: bounds, cornerRadius: bounds.height / 2)
			parameters.visiblePath = capsulePath
		}
		parameters.backgroundColor = .clear
		return parameters
	}
	
}
