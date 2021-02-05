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

protocol TimelineModelDelegate: AnyObject {
	var selectedFeedsPublisher: AnyPublisher<[Feed], Never>? { get }
	func timelineRequestedWebFeedSelection(_: TimelineModel, webFeed: WebFeed)
}

class TimelineModel: ObservableObject, UndoableCommandRunner {
	
	weak var delegate: TimelineModelDelegate?
	
	@Published var nameForDisplay = ""
	@Published var selectedTimelineItemIDs = Set<String>()  // Don't use directly.  Use selectedTimelineItemsPublisher
	@Published var selectedTimelineItemID: String? = nil    // Don't use directly.  Use selectedTimelineItemsPublisher
	@Published var listID = ""
	
	var selectedArticles: [Article] {
		return selectedTimelineItems.map { $0.article }
	}
	
	var timelineItemsPublisher: AnyPublisher<TimelineItems, Never>?
	var timelineItemsSelectPublisher: AnyPublisher<(TimelineItems, String?), Never>?
	var selectedTimelineItemsPublisher: AnyPublisher<[TimelineItem], Never>?
	var selectedArticlesPublisher: AnyPublisher<[Article], Never>?
	var articleStatusChangePublisher: AnyPublisher<Set<String>, Never>?
	var readFilterAndFeedsPublisher: AnyPublisher<([Feed], Bool?), Never>?
	
	var articlesSubject = ReplaySubject<[Article], Never>(bufferSize: 1)

	var changeReadFilterSubject = PassthroughSubject<Bool, Never>()
	var selectNextUnreadSubject = PassthroughSubject<Bool, Never>()

	var readFilterEnabledTable = [FeedIdentifier: Bool]()

	var undoManager: UndoManager?
	var undoableCommands = [UndoableCommand]()

	private var cancellables = Set<AnyCancellable>()

	private var sortDirectionSubject = ReplaySubject<Bool, Never>(bufferSize: 1)
	private var groupByFeedSubject = ReplaySubject<Bool, Never>(bufferSize: 1)

	private var selectedTimelineItems = [TimelineItem]()
	private var timelineItems = TimelineItems()
	private var articles = [Article]()
	
	init(delegate: TimelineModelDelegate) {
		self.delegate = delegate
		subscribeToUserDefaultsChanges()
		subscribeToReadFilterAndFeedChanges()
		subscribeToArticleFetchChanges()
		subscribeToArticleSelectionChanges()
		subscribeToArticleStatusChanges()
	}
	
	// MARK: API
	
	@discardableResult
	func goToNextUnread() -> Bool {
		var startIndex: Int
		if let index = selectedTimelineItems.sorted(by: { $0.position < $1.position }).first?.position {
			startIndex = index + 1
		} else {
			startIndex = 0
		}

		for i in startIndex..<timelineItems.items.count {
			if !timelineItems.items[i].article.status.read {
				let timelineItemID = timelineItems.items[i].id
				selectedTimelineItemIDs = Set([timelineItemID])
				selectedTimelineItemID = timelineItemID
				return true
			}
		}

		return false
	}

	func articleFor(_ articleID: String) -> Article? {
		return timelineItems[articleID]?.article
	}

	func findPrevArticle(_ article: Article) -> Article? {
		guard let index = timelineItems.index[article.articleID], index > 0 else {
			return nil
		}
		return timelineItems.items[index - 1].article
	}
	
	func findNextArticle(_ article: Article) -> Article? {
		guard let index = timelineItems.index[article.articleID], index + 1 != timelineItems.items.count else {
			return nil
		}
		return timelineItems.items[index + 1].article
	}
	
	func selectArticle(_ article: Article) {
		// TODO: Implement me!
	}

	func toggleReadStatusForSelectedArticles() {
		guard !selectedArticles.isEmpty else {
			return
		}
		if selectedArticles.anyArticleIsUnread() {
			markSelectedArticlesAsRead()
		} else {
			markSelectedArticlesAsUnread()
		}
	}

	func canMarkIndicatedArticlesAsRead(_ timelineItem: TimelineItem) -> Bool {
		let articles = indicatedTimelineItems(timelineItem).map { $0.article }
		return articles.anyArticleIsUnread()
	}

	func markIndicatedArticlesAsRead(_ timelineItem: TimelineItem) {
		let articles = indicatedTimelineItems(timelineItem).map { $0.article }
		markArticlesWithUndo(articles, statusKey: .read, flag: true)
	}
	
	func markSelectedArticlesAsRead() {
		markArticlesWithUndo(selectedArticles, statusKey: .read, flag: true)
	}

	func canMarkIndicatedArticlesAsUnread(_ timelineItem: TimelineItem) -> Bool {
		let articles = indicatedTimelineItems(timelineItem).map { $0.article }
		return articles.anyArticleIsReadAndCanMarkUnread()
	}

	func markIndicatedArticlesAsUnread(_ timelineItem: TimelineItem) {
		let articles = indicatedTimelineItems(timelineItem).map { $0.article }
		markArticlesWithUndo(articles, statusKey: .read, flag: false)
	}
	
	func markSelectedArticlesAsUnread() {
		markArticlesWithUndo(selectedArticles, statusKey: .read, flag: false)
	}
	
	func canMarkAboveAsRead(_ timelineItem: TimelineItem) -> Bool {
		let timelineItem = indicatedAboveTimelineItem(timelineItem)
		return articles.articlesAbove(position: timelineItem.position).canMarkAllAsRead()
	}

	func markAboveAsRead(_ timelineItem: TimelineItem) {
		let timelineItem = indicatedAboveTimelineItem(timelineItem)
		let articlesToMark = articles.articlesAbove(position: timelineItem.position)
		guard !articlesToMark.isEmpty else { return }
		markArticlesWithUndo(articlesToMark, statusKey: .read, flag: true)
	}

	func canMarkBelowAsRead(_ timelineItem: TimelineItem) -> Bool {
		let timelineItem = indicatedBelowTimelineItem(timelineItem)
		return articles.articlesBelow(position: timelineItem.position).canMarkAllAsRead()
	}

	func markBelowAsRead(_ timelineItem: TimelineItem) {
		let timelineItem = indicatedBelowTimelineItem(timelineItem)
		let articlesToMark = articles.articlesBelow(position: timelineItem.position)
		guard !articlesToMark.isEmpty else { return }
		markArticlesWithUndo(articlesToMark, statusKey: .read, flag: true)
	}
	
	func canMarkAllAsReadInWebFeed(_ timelineItem: TimelineItem) -> Bool {
		return timelineItem.article.webFeed?.unreadCount ?? 0 > 0
	}
	
	func markAllAsReadInWebFeed(_ timelineItem: TimelineItem) {
		guard let articlesSet = try? timelineItem.article.webFeed?.fetchArticles() else { return	}
		let articlesToMark = Array(articlesSet)
		markArticlesWithUndo(articlesToMark, statusKey: .read, flag: true)
	}
	
	func canMarkAllAsRead() -> Bool {
		return articles.canMarkAllAsRead()
	}
	
	func markAllAsRead() {
		markArticlesWithUndo(articles, statusKey: .read, flag: true)
	}

	func toggleStarredStatusForSelectedArticles() {
		guard !selectedArticles.isEmpty else {
			return
		}
		if selectedArticles.anyArticleIsUnstarred() {
			markSelectedArticlesAsStarred()
		} else {
			markSelectedArticlesAsUnstarred()
		}
	}

	func canMarkIndicatedArticlesAsStarred(_ timelineItem: TimelineItem) -> Bool {
		let articles = indicatedTimelineItems(timelineItem).map { $0.article }
		return articles.anyArticleIsUnstarred()
	}

	func markIndicatedArticlesAsStarred(_ timelineItem: TimelineItem) {
		let articles = indicatedTimelineItems(timelineItem).map { $0.article }
		markArticlesWithUndo(articles, statusKey: .starred, flag: true)
	}

	func markSelectedArticlesAsStarred() {
		markArticlesWithUndo(selectedArticles, statusKey: .starred, flag: true)
	}
	
	func canMarkIndicatedArticlesAsUnstarred(_ timelineItem: TimelineItem) -> Bool {
		let articles = indicatedTimelineItems(timelineItem).map { $0.article }
		return articles.anyArticleIsStarred()
	}

	func markIndicatedArticlesAsUnstarred(_ timelineItem: TimelineItem) {
		let articles = indicatedTimelineItems(timelineItem).map { $0.article }
		markArticlesWithUndo(articles, statusKey: .starred, flag: false)
	}

	func markSelectedArticlesAsUnstarred() {
		markArticlesWithUndo(selectedArticles, statusKey: .starred, flag: false)
	}
	
	func canOpenIndicatedArticleInBrowser(_ timelineItem: TimelineItem) -> Bool {
		guard indicatedTimelineItems(timelineItem).count == 1 else { return false }
		return timelineItem.article.preferredLink != nil
	}
	
	func openSelectedArticleInBrowser() {
		guard let article = selectedArticles.first else { return }
		openIndicatedArticleInBrowser(article)
	}

	func openIndicatedArticleInBrowser(_ timelineItem: TimelineItem) {
		openIndicatedArticleInBrowser(timelineItem.article)
	}
	
	func openIndicatedArticleInBrowser(_ article: Article) {
		guard let link = article.preferredLink else { return }
		
		#if os(macOS)
		Browser.open(link, invertPreference: NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false)
		#else
		guard let url = URL(string: link) else { return }
		UIApplication.shared.open(url, options: [:])
		#endif
	}
}

// MARK: Private

private extension TimelineModel {
	
	// MARK: Subscriptions
	
	func subscribeToArticleStatusChanges() {
		articleStatusChangePublisher = NotificationCenter.default.publisher(for: .StatusesDidChange)
			.compactMap { $0.userInfo?[Account.UserInfoKey.articleIDs] as? Set<String> }
			.eraseToAnyPublisher()
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
	
	func subscribeToReadFilterAndFeedChanges() {
		guard let selectedFeedsPublisher = delegate?.selectedFeedsPublisher else { return }
		
		// Set the timeline name for display
		selectedFeedsPublisher
			.map { feeds -> String in
				switch feeds.count {
				case 0:
					return ""
				case 1:
					return feeds.first!.nameForDisplay
				default:
					return NSLocalizedString("Multiple", comment: "Multiple")
				}
			}
			.assign(to: &$nameForDisplay)
		
		selectedFeedsPublisher
			.map { _ in
				return UUID().uuidString
			}
			.assign(to: &$listID)

		// Clear the selected timeline items when the selected feed(s) change
		selectedFeedsPublisher
			.sink { [weak self] _ in
				self?.selectedTimelineItemIDs = Set<String>()
				self?.selectedTimelineItemID = nil
			}
			.store(in: &cancellables)

		let toggledReadFilterPublisher = changeReadFilterSubject
			.map { Optional($0) }
			.withLatestFrom(selectedFeedsPublisher, resultSelector: { ($1, $0) })
			.share()

		toggledReadFilterPublisher
			.sink { [weak self] (selectedFeeds, readFiltered) in
				if let feedID = selectedFeeds.first?.feedID {
					self?.readFilterEnabledTable[feedID] = readFiltered
				}
			}
			.store(in: &cancellables)
		
		let feedsReadFilterPublisher = selectedFeedsPublisher
			.map { [weak self] feeds -> ([Feed], Bool?) in
				guard let self = self else { return (feeds, nil) }
				
				guard feeds.count == 1, let timelineFeed = feeds.first else {
					return (feeds, nil)
				}
				
				guard timelineFeed.defaultReadFilterType != .alwaysRead else {
					return (feeds, nil)
				}
				
				if let feedID = timelineFeed.feedID, let readFilterEnabled = self.readFilterEnabledTable[feedID] {
					return (feeds, readFilterEnabled)
				} else {
					return (feeds, timelineFeed.defaultReadFilterType == .read)
				}
			}
		
		readFilterAndFeedsPublisher = toggledReadFilterPublisher
			.merge(with: feedsReadFilterPublisher)
			.share(replay: 1)
			.eraseToAnyPublisher()
	}
	
	func subscribeToArticleFetchChanges() {
		guard let readFilterAndFeedsPublisher = readFilterAndFeedsPublisher else { return }
		
		let sortDirectionPublisher = sortDirectionSubject.removeDuplicates()
		let groupByPublisher = groupByFeedSubject.removeDuplicates()
		
		// Download articles and transform them into timeline items
		let inputTimelineItemsPublisher = readFilterAndFeedsPublisher
			.flatMap { (feeds, readFilter) in
				Self.fetchArticlesPublisher(feeds: feeds, isReadFiltered: readFilter)
			}
			.combineLatest(sortDirectionPublisher, groupByPublisher)
			.compactMap { articles, sortDirection, groupBy -> TimelineItems in
				let sortedArticles = Array(articles).sortedByDate(sortDirection ? .orderedDescending : .orderedAscending, groupByFeed: groupBy)
				return Self.buildTimelineItems(articles: sortedArticles)
			}

		guard let selectedFeedsPublisher = delegate?.selectedFeedsPublisher else { return }

		// Subscribe to any article downloads that may need to update the timeline
		let accountDidDownloadPublisher = NotificationCenter.default.publisher(for: .AccountDidDownloadArticles)
			.compactMap { $0.userInfo?[Account.UserInfoKey.webFeeds] as? Set<WebFeed>  }
			.withLatestFrom(selectedFeedsPublisher, resultSelector: { ($0, $1) })
			.map { (noteFeeds, selectedFeeds) in
				return Self.anyFeedIsPseudoFeed(selectedFeeds) || Self.anyFeedIntersection(selectedFeeds, webFeeds: noteFeeds)
			}
			.filter { $0 }
		
		// Download articles and merge them and then transform into timeline items
		let downloadTimelineItemsPublisher = accountDidDownloadPublisher
			.withLatestFrom(readFilterAndFeedsPublisher)
			.flatMap { (feeds, readFilter) in
				Self.fetchArticlesPublisher(feeds: feeds, isReadFiltered: readFilter)
			}
			.withLatestFrom(articlesSubject, sortDirectionPublisher, groupByPublisher, resultSelector: { (downloadArticles, latest) in
				return (downloadArticles, latest.0, latest.1, latest.2)
			})
			.map { (downloadArticles, currentArticles, sortDirection, groupBy) -> TimelineItems in
				let downloadArticleIDs = downloadArticles.articleIDs()
				var updatedArticles = downloadArticles
				
				for article in currentArticles {
					if !downloadArticleIDs.contains(article.articleID) {
						updatedArticles.insert(article)
					}
				}
				
				let sortedArticles = Array(updatedArticles).sortedByDate(sortDirection ? .orderedDescending : .orderedAscending, groupByFeed: groupBy)
				return Self.buildTimelineItems(articles: sortedArticles)
			}

		timelineItemsPublisher = inputTimelineItemsPublisher
			.merge(with: downloadTimelineItemsPublisher)
			.share()
			.eraseToAnyPublisher()

		timelineItemsPublisher!
			.sink { [weak self] timelineItems in
				self?.timelineItems = timelineItems
				self?.articles = timelineItems.items.map { $0.article }
			}
			.store(in: &cancellables)
		
		// Transform to articles for those that just need articles
		timelineItemsPublisher!
			.map { timelineItems in
				timelineItems.items.map { $0.article }
			}
			.sink { [weak self] articles in
				self?.articlesSubject.send(articles)
			}
			.store(in: &cancellables)
		
		// Automatically select the first unread if requested
		timelineItemsSelectPublisher = timelineItemsPublisher!
			.withLatestFrom(selectNextUnreadSubject.prepend(false), resultSelector: { ($0, $1) })
			.map { (timelineItems, selectNextUnread) -> (TimelineItems, String?) in
				var selectTimelineItemID: String? = nil
				if selectNextUnread {
					selectTimelineItemID = timelineItems.items.first(where: { $0.article.status.read == false })?.id
				}
				return (timelineItems, selectTimelineItemID)
			}
			.share(replay: 1)
			.eraseToAnyPublisher()
		
		timelineItemsSelectPublisher!
			.sink { [weak self] _ in
				self?.selectNextUnreadSubject.send(false)
			}
			.store(in: &cancellables)
	}
	
	func subscribeToArticleSelectionChanges() {
		guard let timelineItemsPublisher = timelineItemsPublisher else { return }
		
		let timelineSelectedIDsPublisher = $selectedTimelineItemIDs
			.withLatestFrom(timelineItemsPublisher, resultSelector: { timelineItemIds, timelineItems -> [TimelineItem] in
				return timelineItemIds.compactMap { timelineItems[$0] }
			})
		
		let timelineSelectedIDPublisher = $selectedTimelineItemID
			.withLatestFrom(timelineItemsPublisher, resultSelector: { timelineItemId, timelineItems -> [TimelineItem] in
				if let id = timelineItemId, let item = timelineItems[id] {
					return [item]
				} else {
					return [TimelineItem]()
				}
			})
		
		selectedTimelineItemsPublisher = timelineSelectedIDsPublisher
			.merge(with: timelineSelectedIDPublisher)
			.share(replay: 1)
			.eraseToAnyPublisher()
		
		selectedArticlesPublisher = selectedTimelineItemsPublisher!
			.map { timelineItems in timelineItems.map { $0.article } }
			.share(replay: 1)
			.eraseToAnyPublisher()

		selectedTimelineItemsPublisher!
			.sink { [weak self] selectedTimelineItems in
				self?.selectedTimelineItems = selectedTimelineItems
			}
			.store(in: &cancellables)
		
		// Automatically mark a selected record as read
		selectedTimelineItemsPublisher!
			.filter { $0.count == 1 }
			.compactMap { $0.first?.article }
			.filter { !$0.status.read }
			.sink {	markArticles(Set([$0]), statusKey: .read, flag: true) }
			.store(in: &cancellables)
	}
	
	// MARK: Article Fetching
	
	func fetchArticles(feeds: [Feed], isReadFiltered: Bool?) -> Set<Article> {
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

	static func fetchArticlesPublisher(feeds: [Feed], isReadFiltered: Bool?) -> Future<Set<Article>, Never> {
		return Future<Set<Article>, Never> { promise in
			
			if feeds.isEmpty {
				promise(.success(Set<Article>()))
			}

			#if os(macOS)
			
			var result = Set<Article>()
			
			for feed in feeds {
				if isReadFiltered ?? true {
					if let articles = try? feed.fetchUnreadArticles() {
						result.formUnion(articles)
					}
				} else {
					if let articles = try? feed.fetchArticles() {
						result.formUnion(articles)
					}
				}
			}
			
			promise(.success(result))
			
			#else
			
			let group = DispatchGroup()
			var result = Set<Article>()
			
			for feed in feeds {
				if isReadFiltered ?? true {
					group.enter()
					feed.fetchUnreadArticlesAsync { articleSetResult in
						let articles = (try? articleSetResult.get()) ?? Set<Article>()
						result.formUnion(articles)
						group.leave()
					}
				}
				else {
					group.enter()
					feed.fetchArticlesAsync { articleSetResult in
						let articles = (try? articleSetResult.get()) ?? Set<Article>()
						result.formUnion(articles)
						group.leave()
					}
				}
			}
			
			group.notify(queue: DispatchQueue.main) {
				promise(.success(result))
			}
			
			#endif
			
		}

	}
	
	static func buildTimelineItems(articles: [Article]) -> TimelineItems {
		var items = TimelineItems()
		for (position, article) in articles.enumerated() {
			items.append(TimelineItem(position: position, article: article))
		}
		return items
	}

	static func anyFeedIsPseudoFeed(_ feeds: [Feed]) -> Bool {
		return feeds.contains(where: { $0 is PseudoFeed})
	}

	static func anyFeedIntersection(_ feeds: [Feed], webFeeds: Set<WebFeed>) -> Bool {
		for feed in feeds {
			if let selectedWebFeed = feed as? WebFeed {
				for webFeed in webFeeds {
					if selectedWebFeed.webFeedID == webFeed.webFeedID || selectedWebFeed.url == webFeed.url {
						return true
					}
				}
			} else if let folder = feed as? Folder {
				for webFeed in webFeeds {
					if folder.hasWebFeed(with: webFeed.webFeedID) || folder.hasWebFeed(withURL: webFeed.url) {
						return true
					}
				}
			}
		}
		return false
	}
	
	// MARK: Aricle Marking
	
	func indicatedTimelineItems(_ timelineItem: TimelineItem) -> [TimelineItem] {
		if selectedTimelineItems.contains(where: { $0.id == timelineItem.id }) {
			return selectedTimelineItems
		} else {
			return [timelineItem]
		}
	}
	
	func indicatedAboveTimelineItem(_ timelineItem: TimelineItem) -> TimelineItem {
		if selectedTimelineItems.contains(where: { $0.id == timelineItem.id }) {
			return selectedTimelineItems.sorted(by: { $0.position < $1.position }).first!
		} else {
			return timelineItem
		}
	}
	
	func indicatedBelowTimelineItem(_ timelineItem: TimelineItem) -> TimelineItem {
		if selectedTimelineItems.contains(where: { $0.id == timelineItem.id }) {
			return selectedTimelineItems.sorted(by: { $0.position < $1.position }).last!
		} else {
			return timelineItem
		}
	}
	
	func markArticlesWithUndo(_ articles: [Article], statusKey: ArticleStatus.Key, flag: Bool) {
		if let undoManager = undoManager, let markReadCommand = MarkStatusCommand(initialArticles: articles, statusKey: statusKey, flag: flag, undoManager: undoManager) {
			runCommand(markReadCommand)
		} else {
			markArticles(Set(articles), statusKey: statusKey, flag: flag)
		}
	}
	
}
