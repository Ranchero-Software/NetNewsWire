//
//  TimelineModel.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/30/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif
import Combine
import RSCore
import Account
import Articles

protocol TimelineModelDelegate: class {
	var selectedFeedsPublisher: AnyPublisher<[Feed], Never>? { get }
	func timelineRequestedWebFeedSelection(_: TimelineModel, webFeed: WebFeed)
}

class TimelineModel: ObservableObject, UndoableCommandRunner {
	
	weak var delegate: TimelineModelDelegate?
	
	@Published var nameForDisplay = ""
	@Published var selectedTimelineItemIDs = Set<String>()  // Don't use directly.  Use selectedTimelineItemsPublisher
	@Published var selectedTimelineItemID: String? = nil    // Don't use directly.  Use selectedTimelineItemsPublisher
	@Published var isReadFiltered: Bool? = nil

	var timelineItemsPublisher: AnyPublisher<OrderedDictionary<String, TimelineItem>, Never>?
	var selectedTimelineItemsPublisher: AnyPublisher<[TimelineItem], Never>?

	var readFilterEnabledTable = [FeedIdentifier: Bool]()

	var undoManager: UndoManager?
	var undoableCommands = [UndoableCommand]()

	private var cancellables = Set<AnyCancellable>()

	private var sortDirectionSubject = ReplaySubject<Bool, Never>(bufferSize: 1)
	private var groupByFeedSubject = ReplaySubject<Bool, Never>(bufferSize: 1)
	
	init(delegate: TimelineModelDelegate) {
		self.delegate = delegate
		subscribeToUserDefaultsChanges()
		subscribeToReadFilterChanges()
		subscribeToArticleFetchChanges()
		subscribeToSelectedArticleSelectionChanges()
//		subscribeToArticleStatusChanges()
//		subscribeToAccountDidDownloadArticles()
	}
	
	// MARK: Subscriptions
	
//	func subscribeToArticleStatusChanges() {
//		NotificationCenter.default.publisher(for: .StatusesDidChange).sink { [weak self] note in
//			guard let self = self, let articleIDs = note.userInfo?[Account.UserInfoKey.articleIDs] as? Set<String> else {
//				return
//			}
//			articleIDs.forEach { articleID in
//				if let timelineItemIndex = self.idToTimelineItemDictionary[articleID] {
//					self.timelineItems[timelineItemIndex].updateStatus()
//				}
//			}
//		}.store(in: &cancellables)
//	}
	
//	func subscribeToAccountDidDownloadArticles() {
//		NotificationCenter.default.publisher(for: .AccountDidDownloadArticles).sink { [weak self] note in
//			guard let self = self, let feeds = note.userInfo?[Account.UserInfoKey.webFeeds] as? Set<WebFeed> else {
//				return
//			}
//			if self.anySelectedFeedIntersection(with: feeds) || self.anySelectedFeedIsPseudoFeed() {
//				self.queueFetchAndMergeArticles()
//			}
//		}.store(in: &cancellables)
//	}
	
	func subscribeToReadFilterChanges() {
		guard let selectedFeedsPublisher = delegate?.selectedFeedsPublisher else { return }

		selectedFeedsPublisher.sink { [weak self] feeds in
			guard let self = self else { return }
			
			guard feeds.count == 1, let timelineFeed = feeds.first else {
				self.isReadFiltered = nil
				return
			}
	
			guard timelineFeed.defaultReadFilterType != .alwaysRead else {
				self.isReadFiltered = nil
				return
			}
	
			if let feedID = timelineFeed.feedID, let readFilterEnabled = self.readFilterEnabledTable[feedID] {
				self.isReadFiltered =  readFilterEnabled
			} else {
				self.isReadFiltered = timelineFeed.defaultReadFilterType == .read
			}
		}
		.store(in: &cancellables)
	}
	
	func subscribeToUserDefaultsChanges() {
		let kickStartNote = Notification(name: Notification.Name("Kick Start"))
		NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
			.prepend(kickStartNote)
			.sink { [weak self] _ in
				self?.sortDirectionSubject.send(AppDefaults.shared.timelineSortDirection)
				self?.groupByFeedSubject.send(AppDefaults.shared.timelineGroupByFeed)
		}.store(in: &cancellables)
	}
	
	func subscribeToArticleFetchChanges() {
		guard let selectedFeedsPublisher = delegate?.selectedFeedsPublisher else { return }
		let sortDirectionPublisher = sortDirectionSubject.removeDuplicates()
		let groupByPublisher = groupByFeedSubject.removeDuplicates()
		
		timelineItemsPublisher = selectedFeedsPublisher
			.map { [weak self] feeds -> Set<Article> in
				return self?.fetchArticles(feeds: feeds) ?? Set<Article>()
			}
			.combineLatest(sortDirectionPublisher, groupByPublisher)
			.compactMap { [weak self] articles, sortDirection, groupBy in
				let sortedArticles = Array(articles).sortedByDate(sortDirection ? .orderedDescending : .orderedAscending, groupByFeed: groupBy)
				return self?.buildTimelineItems(articles: sortedArticles) ?? OrderedDictionary<String, TimelineItem>()
			}
			.share(replay: 1)
			.eraseToAnyPublisher()
	}
	
	func subscribeToSelectedArticleSelectionChanges() {
//		$selectedArticleIDs.map { [weak self] articleIDs in
//			return articleIDs.compactMap { self?.idToArticleDictionary[$0] }
//		}
//		.assign(to: &$selectedArticles)
//
//		$selectedArticleID.compactMap { [weak self] articleID in
//			if let articleID = articleID, let article = self?.idToArticleDictionary[articleID] {
//				return [article]
//			} else {
//				return nil
//			}
//		}
//		.assign(to: &$selectedArticles)
//
//		// Assign the selected timeline items
//		$selectedArticles.compactMap { [weak self] selectedArticles in
//			return selectedArticles.compactMap {
//				if let index = self?.idToTimelineItemDictionary[$0.articleID] {
//					return self?.timelineItems[index]
//				}
//				return nil
//			}
//		}.assign(to: &$selectedTimelineItems)
//
//		// Automatically mark a selected record as read
//		$selectedArticles
//			.filter { $0.count == 1 }
//			.compactMap { $0.first }
//			.filter { !$0.status.read }
//			.sink {	markArticles(Set([$0]), statusKey: .read, flag: true) }
//			.store(in: &cancellables)
	}
	
	// MARK: API
	
	func toggleReadFilter() {
//		guard let filter = isReadFiltered, let feedID = feeds.first?.feedID else { return }
//		readFilterEnabledTable[feedID] = !filter
//		isReadFiltered = !filter
//		self.fetchArticles()
	}
	
	func toggleReadStatusForSelectedArticles() {
//		guard !selectedArticles.isEmpty else {
//			return
//		}
//		if selectedArticles.anyArticleIsUnread() {
//			markSelectedArticlesAsRead()
//		} else {
//			markSelectedArticlesAsUnread()
//		}
	}

	@discardableResult
	func goToNextUnread() -> Bool {
//		var startIndex: Int
//		if let firstArticle = selectedArticles.first, let index = timelineItems.firstIndex(where: { $0.article == firstArticle }) {
//			startIndex = index
//		} else {
//			startIndex = 0
//		}
//
//		for i in startIndex..<timelineItems.count {
//			if !timelineItems[i].article.status.read {
//				select(timelineItems[i].article.articleID)
//				return true
//			}
//		}
//
		return false
	}

	func articleFor(_ articleID: String) -> Article? {
		return nil
//		return idToArticleDictionary[articleID]
	}

	func findPrevArticle(_ article: Article) -> Article? {
		return nil
//		guard let index = articles.firstIndex(of: article), index > 0 else {
//			return nil
//		}
//		return articles[index - 1]
	}
	
	func findNextArticle(_ article: Article) -> Article? {
		return nil
//		guard let index = articles.firstIndex(of: article), index + 1 != articles.count else {
//			return nil
//		}
//		return articles[index + 1]
	}
	
	func selectArticle(_ article: Article) {
		// TODO: Implement me!
	}
	
}

// MARK: Private

private extension TimelineModel {
	
	func markArticlesWithUndo(_ articles: [Article], statusKey: ArticleStatus.Key, flag: Bool) {
		if let undoManager = undoManager, let markReadCommand = MarkStatusCommand(initialArticles: articles, statusKey: statusKey, flag: flag, undoManager: undoManager) {
			runCommand(markReadCommand)
		} else {
			markArticles(Set(articles), statusKey: statusKey, flag: flag)
		}
	}
	
	// MARK: Timeline Management

	func sortParametersDidChange() {
//		performBlockAndRestoreSelection {
//			articles = articles.sortedByDate(sortDirection ? .orderedDescending : .orderedAscending, groupByFeed: groupByFeed)
//			rebuildTimelineItems()
//		}
	}
	
	func performBlockAndRestoreSelection(_ block: (() -> Void)) {
//		let savedArticleIDs = selectedArticleIDs
//		let savedArticleID = selectedArticleID
		block()
//		selectedArticleIDs = savedArticleIDs
//		selectedArticleID = savedArticleID
	}
	
	// MARK: Article Fetching
	
	func fetchArticles(feeds: [Feed]) -> Set<Article> {
		if feeds.isEmpty {
			return Set<Article>()
		}

		var fetchedArticles = Set<Article>()
		for feed in feeds {
			if isReadFiltered ?? true {
				if let articles = try? feed.fetchUnreadArticles() {
					fetchedArticles.formUnion(articles)
				}
			} else {
				if let articles = try? feed.fetchArticles() {
					fetchedArticles.formUnion(articles)
				}
			}
		}

		return fetchedArticles
	}	
	
	func buildTimelineItems(articles: [Article]) -> OrderedDictionary<String, TimelineItem> {
		var items = OrderedDictionary<String, TimelineItem>()
		for (index, article) in articles.enumerated() {
			let item = TimelineItem(index: index, article: article)
			items[item.id] = item
		}
		return items
	}

//	func anySelectedFeedIsPseudoFeed() -> Bool {
//		return feeds.contains(where: { $0 is PseudoFeed})
//	}
//
//	func anySelectedFeedIntersection(with webFeeds: Set<WebFeed>) -> Bool {
//		for feed in feeds {
//			if let selectedWebFeed = feed as? WebFeed {
//				for webFeed in webFeeds {
//					if selectedWebFeed.webFeedID == webFeed.webFeedID || selectedWebFeed.url == webFeed.url {
//						return true
//					}
//				}
//			} else if let folder = feed as? Folder {
//				for webFeed in webFeeds {
//					if folder.hasWebFeed(with: webFeed.webFeedID) || folder.hasWebFeed(withURL: webFeed.url) {
//						return true
//					}
//				}
//			}
//		}
//		return false
//	}
}
