//
//  CloudKitFeedRefresher.swift
//  Account
//
//  Created by Maurice Parker on 4/25/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSWeb
import Articles

final class CloudKitFeedRefresher {
	
	private var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CloudKit")

	weak var refreshProgress: DownloadProgress?
	weak var refresher: LocalAccountRefresher?
	weak var articlesZone: CloudKitArticlesZone?
	
	init(refreshProgress: DownloadProgress?, refresher: LocalAccountRefresher?, articlesZone: CloudKitArticlesZone?) {
		self.refreshProgress = refreshProgress
		self.refresher = refresher
		self.articlesZone = articlesZone
	}
	
	func refresh(_ account: Account, _ webFeeds: Set<WebFeed>, completion: @escaping () -> Void) {
		guard let refreshProgress = refreshProgress, let refresher = refresher, let articlesZone = articlesZone else { return }
		
		var newArticles = Set<Article>()
		var deletedArticles = Set<Article>()

		var refresherWebFeeds = Set<WebFeed>()
		let group = DispatchGroup()
		
		refreshProgress.addToNumberOfTasksAndRemaining(2)
		
		for webFeed in webFeeds {
			if let components = URLComponents(string: webFeed.url), let feedProvider = FeedProviderManager.shared.best(for: components) {
				group.enter()
				feedProvider.refresh(webFeed) { result in
					switch result {
					case .success(let parsedItems):
						
						account.update(webFeed.webFeedID, with: parsedItems) { result in
							switch result {
							case .success(let articleChanges):
								
								newArticles.formUnion(articleChanges.newArticles ?? Set<Article>())
								deletedArticles.formUnion(articleChanges.deletedArticles ?? Set<Article>())

								refreshProgress.completeTask()
								group.leave()
								
							case .failure(let error):
								os_log(.error, log: self.log, "CloudKit Feed refresh update error: %@.", error.localizedDescription)
								refreshProgress.completeTask()
								group.leave()
							}
							
						}

					case .failure(let error):
						os_log(.error, log: self.log, "CloudKit Feed refresh error: %@.", error.localizedDescription)
						refreshProgress.completeTask()
						group.leave()
					}
				}
			} else {
				refresherWebFeeds.insert(webFeed)
			}
		}
		
		group.enter()
		refresher.refreshFeeds(refresherWebFeeds) {
			group.leave()
		}
		
		group.notify(queue: DispatchQueue.main) {
			
			articlesZone.deleteArticles(deletedArticles) { _ in
				refreshProgress.completeTask()
				articlesZone.sendNewArticles(newArticles) { _ in
					refreshProgress.completeTask()
					completion()
				}
			}
			
		}

	}
	
}
