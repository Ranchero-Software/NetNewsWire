//
//  MasterTimelineViewController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore
import Account
import Articles

class MasterTimelineViewController: ProgressTableViewController, UndoableCommandRunner {

	private static var minAvatarDimension: CGFloat = 20.0
	
	@IBOutlet weak var markAllAsReadButton: UIBarButtonItem!
	@IBOutlet weak var firstUnreadButton: UIBarButtonItem!
	
	weak var navState: NavigationStateController?
	var undoableCommands = [UndoableCommand]()
	
	override var canBecomeFirstResponder: Bool {
		return true
	}
	
	override func viewDidLoad() {
		
		super.viewDidLoad()
		
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(statusesDidChange(_:)), name: .StatusesDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(feedIconDidBecomeAvailable(_:)), name: .FeedIconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(avatarDidBecomeAvailable(_:)), name: .AvatarDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(imageDidBecomeAvailable(_:)), name: .ImageDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(imageDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(articlesReinitialized(_:)), name: .ArticlesReinitialized, object: navState)
		NotificationCenter.default.addObserver(self, selector: #selector(articleDataDidChange(_:)), name: .ArticleDataDidChange, object: navState)
		NotificationCenter.default.addObserver(self, selector: #selector(articlesDidChange(_:)), name: .ArticlesDidChange, object: navState)
		NotificationCenter.default.addObserver(self, selector: #selector(articleSelectionDidChange(_:)), name: .ArticleSelectionDidChange, object: navState)
		NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange), name: UIContentSizeCategory.didChangeNotification, object: nil)

		refreshControl = UIRefreshControl()
		refreshControl!.addTarget(self, action: #selector(refreshAccounts(_:)), for: .valueChanged)
		
		resetUI()
		
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		becomeFirstResponder()
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		resignFirstResponder()
	}

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "showDetail" {
			let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
			controller.navState = navState
			controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
			controller.navigationItem.leftItemsSupplementBackButton = true
			splitViewController?.toggleMasterView()
		}
	}
	
	// MARK Actions

	@IBAction func markAllAsRead(_ sender: Any) {
		
		let title = NSLocalizedString("Mark All Read", comment: "Mark All Read")
		let message = NSLocalizedString("Mark all articles in this timeline as read?", comment: "Mark all articles")
		let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)

		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
		let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel)
		alertController.addAction(cancelAction)
		
		let markTitle = NSLocalizedString("Mark All Read", comment: "Mark All Read")
		let markAction = UIAlertAction(title: markTitle, style: .default) { [weak self] (action) in

			guard let articles = self?.navState?.articles,
				let undoManager = self?.undoManager,
				let markReadCommand = MarkStatusCommand(initialArticles: articles, markingRead: true, undoManager: undoManager) else {
				return
			}
			self?.runCommand(markReadCommand)
			
		}
		alertController.addAction(markAction)
		
		present(alertController, animated: true)
		
	}
	
	@IBAction func firstUnread(_ sender: Any) {
		if let indexPath = navState?.firstUnreadArticleIndexPath {
			tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
		}
	}
	
	// MARK: - Table view

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return navState?.articles.count ?? 0
    }

	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		
		guard let article = navState?.articles[indexPath.row] else {
			return nil
		}
		
		// Set up the read action
		let readTitle = article.status.read ?
			NSLocalizedString("Unread", comment: "Unread") :
			NSLocalizedString("Read", comment: "Read")
		
		let readAction = UIContextualAction(style: .normal, title: readTitle) { [weak self] (action, view, completionHandler) in
			guard let undoManager = self?.undoManager,
				let markReadCommand = MarkStatusCommand(initialArticles: [article], markingRead: !article.status.read, undoManager: undoManager) else {
					return
			}
			self?.runCommand(markReadCommand)
			completionHandler(true)
		}
		
		readAction.image = AppAssets.circleClosedImage
		readAction.backgroundColor = AppAssets.timelineUnreadCircleColor
		
		// Set up the star action
		let starTitle = article.status.starred ?
			NSLocalizedString("Unstar", comment: "Unstar") :
			NSLocalizedString("Star", comment: "Star")
		
		let starAction = UIContextualAction(style: .normal, title: starTitle) { [weak self] (action, view, completionHandler) in
			guard let undoManager = self?.undoManager,
				let markReadCommand = MarkStatusCommand(initialArticles: [article], markingStarred: !article.status.starred, undoManager: undoManager) else {
					return
			}
			self?.runCommand(markReadCommand)
			completionHandler(true)
		}
		
		starAction.image = AppAssets.starClosedImage
		starAction.backgroundColor = AppAssets.starColor
		
		let configuration = UISwipeActionsConfiguration(actions: [readAction, starAction])
		return configuration
		
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		
		let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! MasterTimelineTableViewCell

		guard let article = navState?.articles[indexPath.row] else {
			return cell
		}

		configureTimelineCell(cell, article: article)
		
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		navState?.currentArticleIndexPath = indexPath
	}
	
	// MARK: Notifications

	@objc dynamic func unreadCountDidChange(_ notification: Notification) {
		updateUI()
	}
	
	@objc func statusesDidChange(_ note: Notification) {
		
		guard let articles = note.userInfo?[Account.UserInfoKey.articles] as? Set<Article> else {
			return
		}
		reloadVisibleCells(for: articles)
	}

	@objc func feedIconDidBecomeAvailable(_ note: Notification) {
		
		guard let feed = note.userInfo?[UserInfoKey.feed] as? Feed else {
			return
		}
		
		performBlockAndRestoreSelection {
			tableView.indexPathsForVisibleRows?.forEach { indexPath in
				
				guard let article = navState?.articles.articleAtRow(indexPath.row) else {
					return
				}
				
				if feed == article.feed {
					tableView.reloadRows(at: [indexPath], with: .none)
					return
				}
				
			}
		}

	}

	@objc func avatarDidBecomeAvailable(_ note: Notification) {
		
		guard navState?.showAvatars ?? false, let avatarURL = note.userInfo?[UserInfoKey.url] as? String else {
			return
		}
		
		performBlockAndRestoreSelection {
			tableView.indexPathsForVisibleRows?.forEach { indexPath in
				
				guard let article = navState?.articles.articleAtRow(indexPath.row), let authors = article.authors, !authors.isEmpty else {
					return
				}
				
				for author in authors {
					if author.avatarURL == avatarURL {
						tableView.reloadRows(at: [indexPath], with: .none)
					}
				}

			}
		}
		
	}

	@objc func imageDidBecomeAvailable(_ note: Notification) {
		if navState?.showAvatars ?? false {
			queueReloadVisableCells()
		}
	}

	@objc func articlesReinitialized(_ note: Notification) {
		resetUI()
	}
	
	@objc func articleDataDidChange(_ note: Notification) {
		reloadAllVisibleCells()
	}
	
	@objc func articlesDidChange(_ note: Notification) {
		performBlockAndRestoreSelection {
			tableView.reloadData()
		}
	}
	
	@objc func articleSelectionDidChange(_ note: Notification) {
		
		if let indexPath = navState?.currentArticleIndexPath {
			if tableView.indexPathForSelectedRow != indexPath {
				tableView.selectRow(at: indexPath, animated: true, scrollPosition: .middle)
			}
		}
		
		updateUI()
		
	}

	@objc func contentSizeCategoryDidChange(_ note: Notification) {
		tableView.reloadData()
	}
	
	// MARK: Reloading
	
	@objc func reloadAllVisibleCells() {
		tableView.beginUpdates()
		performBlockAndRestoreSelection {
			tableView.reloadRows(at: tableView.indexPathsForVisibleRows!, with: .none)
		}
		tableView.endUpdates()
	}
	
	private func reloadVisibleCells(for articles: [Article]) {
		reloadVisibleCells(for: Set(articles.articleIDs()))
	}
	
	private func reloadVisibleCells(for articles: Set<Article>) {
		reloadVisibleCells(for: articles.articleIDs())
	}
	
	private func reloadVisibleCells(for articleIDs: Set<String>) {
		if articleIDs.isEmpty {
			return
		}
		if let indexes = navState?.indexesForArticleIDs(articleIDs) {
			reloadVisibleCells(for: indexes)
		}
	}
	
	private func reloadVisibleCells(for indexes: IndexSet) {
		performBlockAndRestoreSelection {
			tableView.indexPathsForVisibleRows?.forEach { indexPath in
				if indexes.contains(indexPath.row) {
					tableView.reloadRows(at: [indexPath], with: .none)
				}
			}
		}
	}
	
}

// MARK: Private

private extension MasterTimelineViewController {

	@objc private func refreshAccounts(_ sender: Any) {
		AccountManager.shared.refreshAll()
		refreshControl?.endRefreshing()
	}

	func resetUI() {
		
		title = navState?.timelineName
		navigationController?.title = navState?.timelineName
		
		if navState?.articles.count ?? 0 > 0 {
			tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
		}
		
		updateUI()
		
	}
	
	func updateUI() {
		markAllAsReadButton.isEnabled = navState?.isTimelineUnreadAvailable ?? false
		firstUnreadButton.isEnabled = navState?.isTimelineUnreadAvailable ?? false
	}
	
	func configureTimelineCell(_ cell: MasterTimelineTableViewCell, article: Article) {
		
		let avatar = avatarFor(article)
		let featuredImage = featuredImageFor(article)
		
		let showFeedNames = navState?.showFeedNames ?? false
		let showAvatar = navState?.showAvatars ?? false && avatar != nil
		cell.cellData = MasterTimelineCellData(article: article, showFeedName: showFeedNames, feedName: article.feed?.nameForDisplay, avatar: avatar, showAvatar: showAvatar, featuredImage: featuredImage)
		
	}
	
	func avatarFor(_ article: Article) -> UIImage? {
		
		if !(navState?.showAvatars ?? false) {
			return nil
		}
		
		if let authors = article.authors {
			for author in authors {
				if let image = avatarForAuthor(author), imagePassesQualityAssurance(image) {
					return image
				}
			}
		}
		
		guard let feed = article.feed else {
			return nil
		}
		
		let feedIconImage = appDelegate.feedIconDownloader.icon(for: feed)
		if imagePassesQualityAssurance(feedIconImage) {
			return feedIconImage
		}
		
		if let feed = article.feed, let faviconImage = appDelegate.faviconDownloader.favicon(for: feed) {
			if imagePassesQualityAssurance(faviconImage) {
				return faviconImage
			}
		}
		
		return FaviconGenerator.favicon(feed)
		
	}
	
	func imagePassesQualityAssurance(_ image: UIImage?) -> Bool {
		let minDimension = MasterTimelineViewController.minAvatarDimension * RSScreen.mainScreenScale
		if let image = image, image.size.height >= minDimension, image.size.width >= minDimension {
			return true
		}
		return false
	}
	
	func avatarForAuthor(_ author: Author) -> UIImage? {
		return appDelegate.authorAvatarDownloader.image(for: author)
	}
	
	func featuredImageFor(_ article: Article) -> UIImage? {
		if let url = article.imageURL, let data = appDelegate.imageDownloader.image(for: url) {
			return RSImage(data: data)
		}
		return nil
	}

	func queueReloadVisableCells() {
		CoalescingQueue.standard.add(self, #selector(reloadAllVisibleCells))
	}

	func performBlockAndRestoreSelection(_ block: (() -> Void)) {
		let indexPaths = tableView.indexPathsForSelectedRows
		block()
		indexPaths?.forEach { [weak self] indexPath in
			self?.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
		}
	}
	
}
