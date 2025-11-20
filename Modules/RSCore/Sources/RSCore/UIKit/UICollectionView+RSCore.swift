//
//  UICollectionView-Extensions.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 15/07/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

#if os(iOS)

import Foundation
import UIKit

extension UICollectionView {
	
	/// Selects an item and scrolls it to the middle if it is not visible
	public func selectItemAndScrollIfNotVisible(at indexPath: IndexPath, animations: Animations) {
		guard let dataSource = dataSource,
			let numberOfSections = dataSource.numberOfSections,
			indexPath.section < numberOfSections(self),
			indexPath.row < dataSource.collectionView(self, numberOfItemsInSection: indexPath.section) else {
				return
		}

		selectItem(at: indexPath, animated: animations.contains(.select), scrollPosition: [])

		if  !indexPathsForVisibleItems.contains(indexPath) {
			scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
		}
	}

}

#endif
