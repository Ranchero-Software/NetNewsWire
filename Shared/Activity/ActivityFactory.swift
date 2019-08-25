//
//  ActivityFactory.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 8/23/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import CoreSpotlight
import CoreServices
import Articles

class ActivityFactory {
	
	static func make(_ article: Article) -> NSUserActivity {
		let activity = NSUserActivity(activityType: ActivityType.readArticle.rawValue)

		activity.title = article.title
		
		let feedNameKeywords = article.feed?.nameForDisplay.components(separatedBy: " ").filter { $0.count > 2 } ?? []
		let articleTitleKeywords = article.title?.components(separatedBy: " ").filter { $0.count > 2 } ?? []
		let keywords = feedNameKeywords + articleTitleKeywords
		activity.keywords = Set(keywords)
		
		activity.userInfo = [
			ActivityID.accountID.rawValue: article.accountID,
			ActivityID.accountName.rawValue: article.account?.name ?? "",
			ActivityID.feedID.rawValue: article.feedID,
			ActivityID.articleID.rawValue: article.articleID
		]
		activity.isEligibleForSearch = true
		activity.isEligibleForPrediction = false
		activity.isEligibleForHandoff = true
		
		// CoreSpotlight
		let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeCompositeContent as String)
		attributeSet.title = article.title
		attributeSet.contentDescription = article.summary
		attributeSet.keywords = keywords
		attributeSet.relatedUniqueIdentifier = article.url
		
		if let image = article.avatarImage() {
			attributeSet.thumbnailData = image.pngData()
		}
		
		activity.contentAttributeSet = attributeSet
		
		return activity
	}
	
}
