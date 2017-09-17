//
//  Folder+Container.swift
//  Account
//
//  Created by Brent Simmons on 9/16/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Data

extension Folder: Container {

	public func flattenedFeeds() -> Set<Feed> {

		var feeds = Set<Feed>()
		for oneChild in childObjects {
			if let oneFeed = oneChild as? Feed {
				feeds.insert(oneFeed)
			}
			else if let oneContainer = oneChild as? Container {
				feeds.formUnion(oneContainer.flattenedFeeds())
			}
		}
		return feeds
	}

	public func isChild(_ obj: AnyObject) -> Bool {

		return childObjects.contains(where: { (oneObject) -> Bool in
			return oneObject === obj
		})
	}

	public func visitObjects(_ recurse: Bool, _ visitBlock: VisitBlock) -> Bool {

		for oneObject in childObjects {

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

