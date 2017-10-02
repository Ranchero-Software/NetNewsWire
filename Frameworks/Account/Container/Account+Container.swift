//
//  Account+Container.swift
//  Account
//
//  Created by Brent Simmons on 9/16/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Data

extension Account: Container {

	public func flattenedFeeds() -> Set<Feed> {

		return Set(feedIDDictionary.values)
	}

	public func existingFeed(with feedID: String) -> Feed? {

		return feedIDDictionary[feedID]
	}

	public func canAddItem(_ item: AnyObject) -> Bool {

		return false // TODO
	}

	public func isChild(_ obj: AnyObject) -> Bool {

		return topLevelObjects.contains(where: { (oneObject) -> Bool in
			return oneObject === obj
		})
	}

	public func visitObjects(_ recurse: Bool, _ visitBlock: VisitBlock) -> Bool {

		for oneObject in topLevelObjects {

			if let oneContainer = oneObject as? Container {
				if visitBlock(oneObject) {
					return true
				}
				if recurse && oneContainer.visitObjects(recurse, visitBlock) {
					return true
				}
			}
			else {
				if visitBlock(oneObject) {
					return true
				}
			}
		}

		return false
	}
}
