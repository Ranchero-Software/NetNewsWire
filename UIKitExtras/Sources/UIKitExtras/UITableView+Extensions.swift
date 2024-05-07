//
//  UITableView-Extensions.swift
//  RSCoreiOS
//
//  Created by Maurice Parker on 9/6/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import UIKit

extension UITableView {
	
	/**
	Selects a row and scrolls it to the middle if it is not visible
	*/
	public func selectRowAndScrollIfNotVisible(at indexPath: IndexPath, animations: Animations) {
		guard let dataSource = dataSource,
			let numberOfSections = dataSource.numberOfSections,
			indexPath.section < numberOfSections(self),
			indexPath.row < dataSource.tableView(self, numberOfRowsInSection: indexPath.section) else {
				return
		}
		
		selectRow(at: indexPath, animated: animations.contains(.select), scrollPosition: .none)

		if let visibleIndexPaths = indexPathsForRows(in: safeAreaLayoutGuide.layoutFrame) {
			if !(visibleIndexPaths.contains(indexPath) && cellCompletelyVisible(indexPath)) {
				scrollToRow(at: indexPath, at: .middle, animated: animations.contains(.scroll))
			}
		}
	}
	
	func cellCompletelyVisible(_ indexPath: IndexPath) -> Bool {
		let rect = rectForRow(at: indexPath)
		return safeAreaLayoutGuide.layoutFrame.contains(rect)
	}
	
	public func middleVisibleRow() -> IndexPath? {
		if let visibleIndexPaths = indexPathsForRows(in: safeAreaLayoutGuide.layoutFrame), visibleIndexPaths.count > 2 {
			return visibleIndexPaths[visibleIndexPaths.count / 2]
		}
		return nil
	}
}
