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

class MasterTimelineViewController: UITableViewController, UndoableCommandRunner {

	private var numberOfTextLines = 0
	
	@IBOutlet weak var markAllAsReadButton: UIBarButtonItem!
	@IBOutlet weak var firstUnreadButton: UIBarButtonItem!
	
	weak var coordinator: AppCoordinator!
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
		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(progressDidChange(_:)), name: .AccountRefreshProgressDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange), name: UIContentSizeCategory.didChangeNotification, object: nil)

		refreshControl = UIRefreshControl()
		refreshControl!.addTarget(self, action: #selector(refreshAccounts(_:)), for: .valueChanged)
		
		numberOfTextLines = AppDefaults.timelineNumberOfLines
		resetEstimatedRowHeight()
		
		resetUI()
		
	}
	
	override func viewWillAppear(_ animated: Bool) {
		clearsSelectionOnViewWillAppear = coordinator.isRootSplitCollapsed
		super.viewWillAppear(animated)
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		becomeFirstResponder()
		updateProgressIndicatorIfNeeded()
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		resignFirstResponder()
	}

	override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		super.traitCollectionDidChange(previousTraitCollection)
		
		if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
			appDelegate.authorAvatarDownloader.resetCache()
			appDelegate.feedIconDownloader.resetCache()
			appDelegate.faviconDownloader.resetCache()
			performBlockAndRestoreSelection {
				tableView.reloadData()
			}
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
			self?.coordinator.markAllAsReadInTimeline()
		}
		
		alertController.addAction(markAction)
		
		present(alertController, animated: true)
		
	}
	
	@IBAction func firstUnread(_ sender: Any) {
		coordinator.selectNextUnread()
	}
	
	// MARK: API
	
	func reinitializeArticles() {
		resetUI()
	}
	
	func updateArticles() {
		reloadAllVisibleCells()
	}
	
	func reloadArticles() {
		performBlockAndRestoreSelection {
			tableView.reloadData()
		}
	}
	
	func updateArticleSelection() {
		if let indexPath = coordinator.currentArticleIndexPath {
			if tableView.indexPathForSelectedRow != indexPath {
				tableView.selectRow(at: indexPath, animated: true, scrollPosition: .middle)
			}
		}
		updateUI()
	}

	// MARK: - Table view

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return coordinator.articles.count
    }

	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		
		let article = coordinator.articles[indexPath.row]
		
		// Set up the read action
		let readTitle = article.status.read ?
			NSLocalizedString("Unread", comment: "Unread") :
			NSLocalizedString("Read", comment: "Read")
		
		let readAction = UIContextualAction(style: .normal, title: readTitle) { [weak self] (action, view, completionHandler) in
			self?.coordinator.toggleRead(for: indexPath)
			completionHandler(true)
		}
		
		readAction.image = AppAssets.circleClosedImage
		readAction.backgroundColor = AppAssets.netNewsWireBlueColor
		
		// Set up the star action
		let starTitle = article.status.starred ?
			NSLocalizedString("Unstar", comment: "Unstar") :
			NSLocalizedString("Star", comment: "Star")
		
		let starAction = UIContextualAction(style: .normal, title: starTitle) { [weak self] (action, view, completionHandler) in
			self?.coordinator.toggleStar(for: indexPath)
			completionHandler(true)
		}
		
		starAction.image = AppAssets.starClosedImage
		starAction.backgroundColor = AppAssets.starColor
		
		// Set up the read action
		let moreTitle = NSLocalizedString("More", comment: "More")
		let moreAction = UIContextualAction(style: .normal, title: moreTitle) { [weak self] (action, view, completionHandler) in
			
			if let self = self {
			
				let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
				if let popoverController = alert.popoverPresentationController {
					popoverController.sourceView = view
					popoverController.sourceRect = CGRect(x: view.frame.size.width/2, y: view.frame.size.height/2, width: 1, height: 1)
				}
				
				alert.addAction(self.markOlderAsReadAlertAction(indexPath: indexPath, completionHandler: completionHandler))
				
				if let action = self.discloseFeedAlertAction(indexPath: indexPath, completionHandler: completionHandler) {
					alert.addAction(action)
				}
				
				if let action = self.markAllInFeedAsReadAlertAction(indexPath: indexPath, completionHandler: completionHandler) {
					alert.addAction(action)
				}

				if let action = self.openInBrowserAlertAction(indexPath: indexPath, completionHandler: completionHandler) {
					alert.addAction(action)
				}

				if let action = self.shareAlertAction(indexPath: indexPath, completionHandler: completionHandler) {
					alert.addAction(action)
				}

				let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
				alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel) { _ in
					completionHandler(true)
				})

				self.present(alert, animated: true)
				
			}
			
		}
		
		moreAction.image = AppAssets.moreImage
		moreAction.backgroundColor = UIColor.systemGray

		let configuration = UISwipeActionsConfiguration(actions: [readAction, starAction, moreAction])
		return configuration
		
	}

	override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {

		return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { [weak self] suggestedActions in

			guard let self = self else { return nil }
			
			var actions = [UIAction]()
			actions.append(self.toggleArticleReadStatusAction(indexPath: indexPath))
			actions.append(self.toggleArticleStarStatusAction(indexPath: indexPath))
			actions.append(self.markOlderAsReadAction(indexPath: indexPath))
			
			if let action = self.discloseFeedAction(indexPath: indexPath) {
				actions.append(action)
			}
			
			if let action = self.markAllInFeedAsReadAction(indexPath: indexPath) {
				actions.append(action)
			}
			
			if let action = self.openInBrowserAction(indexPath: indexPath) {
				actions.append(action)
			}
			
			if let action = self.shareAction(indexPath: indexPath) {
				actions.append(action)
			}
			
			return UIMenu(title: "", children: actions)

		})
		
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! MasterTimelineTableViewCell
		let article = coordinator.articles[indexPath.row]
		configureTimelineCell(cell, article: article)
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		coordinator.selectArticle(indexPath)
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
				guard let article = coordinator.articles.articleAtRow(indexPath.row) else {
					return
				}
				if article.feed == feed, let cell = tableView.cellForRow(at: indexPath) as? MasterTimelineTableViewCell, let image = avatarFor(article) {
					cell.setAvatarImage(image)
				}
			}
		}
	}

	@objc func avatarDidBecomeAvailable(_ note: Notification) {
		guard coordinator.showAvatars, let avatarURL = note.userInfo?[UserInfoKey.url] as? String else {
			return
		}
		
		performBlockAndRestoreSelection {
			tableView.indexPathsForVisibleRows?.forEach { indexPath in
				guard let article = coordinator.articles.articleAtRow(indexPath.row), let authors = article.authors, !authors.isEmpty else {
					return
				}
				for author in authors {
					if author.avatarURL == avatarURL, let cell = tableView.cellForRow(at: indexPath) as? MasterTimelineTableViewCell, let image = avatarFor(article) {
						cell.setAvatarImage(image)
					}
				}
			}
		}
	}

	@objc func faviconDidBecomeAvailable(_ note: Notification) {
		guard coordinator.showAvatars, let faviconURL = note.userInfo?["faviconURL"] as? String else {
			return
		}
		
		performBlockAndRestoreSelection {
			tableView.indexPathsForVisibleRows?.forEach { indexPath in
				
				guard let article = coordinator.articles.articleAtRow(indexPath.row), let articleFaviconURL = article.feed?.faviconURL else {
					return
				}
				if faviconURL == articleFaviconURL, let cell = tableView.cellForRow(at: indexPath) as? MasterTimelineTableViewCell, let image = avatarFor(article) {
					cell.setAvatarImage(image)
					return
				}

			}
		}
	}

	@objc func userDefaultsDidChange(_ note: Notification) {
		if numberOfTextLines != AppDefaults.timelineNumberOfLines {
			numberOfTextLines = AppDefaults.timelineNumberOfLines
			resetEstimatedRowHeight()
			tableView.reloadData()
		}
	}
	
	@objc func contentSizeCategoryDidChange(_ note: Notification) {
		tableView.reloadData()
	}
	
	@objc func progressDidChange(_ note: Notification) {
		updateProgressIndicatorIfNeeded()
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
		let indexes = coordinator.indexesForArticleIDs(articleIDs)
		reloadVisibleCells(for: indexes)
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
	
	// MARK: Cell Configuring

	private func resetEstimatedRowHeight() {
		
		let longTitle = "But I must explain to you how all this mistaken idea of denouncing pleasure and praising pain was born and I will give you a complete account of the system, and expound the actual teachings of the great explorer of the truth, the master-builder of human happiness. No one rejects, dislikes, or avoids pleasure itself, because it is pleasure, but because those who do not know how to pursue pleasure rationally encounter consequences that are extremely painful. Nor again is there anyone who loves or pursues or desires to obtain pain of itself, because it is pain, but because occasionally circumstances occur in which toil and pain can procure him some great pleasure. To take a trivial example, which of us ever undertakes laborious physical exercise, except to obtain some advantage from it? But who has any right to find fault with a man who chooses to enjoy a pleasure that has no annoying consequences, or one who avoids a pain that produces no resultant pleasure?"
		
		let prototypeID = "prototype"
		let status = ArticleStatus(articleID: prototypeID, read: false, starred: false, userDeleted: false, dateArrived: Date())
		let prototypeArticle = Article(accountID: prototypeID, articleID: prototypeID, feedID: prototypeID, uniqueID: prototypeID, title: longTitle, contentHTML: nil, contentText: nil, url: nil, externalURL: nil, summary: nil, imageURL: nil, bannerImageURL: nil, datePublished: nil, dateModified: nil, authors: nil, attachments: nil, status: status)
		
		let prototypeCellData = MasterTimelineCellData(article: prototypeArticle, showFeedName: true, feedName: "Prototype Feed Name", avatar: nil, showAvatar: false, featuredImage: nil, numberOfLines: numberOfTextLines)
		
		if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
			let layout = MasterTimelineAccessibilityCellLayout(width: tableView.bounds.width, insets: tableView.safeAreaInsets, cellData: prototypeCellData)
			tableView.estimatedRowHeight = layout.height
		} else {
			let layout = MasterTimelineDefaultCellLayout(width: tableView.bounds.width, insets: tableView.safeAreaInsets, cellData: prototypeCellData)
			tableView.estimatedRowHeight = layout.height
		}
		
	}
	
}

// MARK: Private

private extension MasterTimelineViewController {

	@objc private func refreshAccounts(_ sender: Any) {
		refreshControl?.endRefreshing()
		// This is a hack to make sure that an error dialog doesn't interfere with dismissing the refreshControl.
		// If the error dialog appears too closely to the call to endRefreshing, then the refreshControl never disappears.
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			AccountManager.shared.refreshAll(errorHandler: ErrorHandler.present(self))
		}
	}

	func resetUI() {
		
		title = coordinator.timelineName
		navigationController?.title = coordinator.timelineName
		
		tableView.selectRow(at: nil, animated: false, scrollPosition: .top)
		if coordinator.articles.count > 0 {
			tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
		}
		
		updateUI()
		
	}
	
	func updateUI() {
		markAllAsReadButton.isEnabled = coordinator.isTimelineUnreadAvailable
		firstUnreadButton.isEnabled = coordinator.isTimelineUnreadAvailable
	}
	
	func updateProgressIndicatorIfNeeded() {
		if !coordinator.isThreePanelMode {
			navigationController?.updateAccountRefreshProgressIndicator()
		}
	}
	
	func configureTimelineCell(_ cell: MasterTimelineTableViewCell, article: Article) {
		
		let avatar = avatarFor(article)
		let featuredImage = featuredImageFor(article)
		
		let showFeedNames = coordinator.showFeedNames
		let showAvatar = coordinator.showAvatars && avatar != nil
		cell.cellData = MasterTimelineCellData(article: article, showFeedName: showFeedNames, feedName: article.feed?.nameForDisplay, avatar: avatar, showAvatar: showAvatar, featuredImage: featuredImage, numberOfLines: numberOfTextLines)
		
	}
	
	func avatarFor(_ article: Article) -> RSImage? {
		if !coordinator.showAvatars {
			return nil
		}
		return article.avatarImage()
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
	
	func toggleArticleReadStatusAction(indexPath: IndexPath) -> UIAction {
		let article = coordinator.articles[indexPath.row]

		let title = article.status.read ?
			NSLocalizedString("Mark as Unread", comment: "Mark as Unread") :
			NSLocalizedString("Mark as Read", comment: "Mark as Read")
		let image = article.status.read ? AppAssets.circleClosedImage : AppAssets.circleOpenImage

		let action = UIAction(title: title, image: image) { [weak self] action in
			self?.coordinator.toggleRead(for: indexPath)
		}
		
		return action
	}
	
	func toggleArticleStarStatusAction(indexPath: IndexPath) -> UIAction {
		let article = coordinator.articles[indexPath.row]

		let title = article.status.starred ?
			NSLocalizedString("Mark as Unstarred", comment: "Mark as Unstarred") :
			NSLocalizedString("Mark as Starred", comment: "Mark as Starred")
		let image = article.status.starred ? AppAssets.starOpenImage : AppAssets.starClosedImage

		let action = UIAction(title: title, image: image) { [weak self] action in
			self?.coordinator.toggleStar(for: indexPath)
		}
		
		return action
	}
	
	func markOlderAsReadAction(indexPath: IndexPath) -> UIAction {
		let title = NSLocalizedString("Mark Older as Read", comment: "Mark Older as Read")
		let image = coordinator.sortDirection == .orderedDescending ? AppAssets.markOlderAsReadDownImage : AppAssets.markOlderAsReadUpImage
		let action = UIAction(title: title, image: image) { [weak self] action in
			self?.coordinator.markAsReadOlderArticlesInTimeline(indexPath)
		}
		return action
	}
	
	func markOlderAsReadAlertAction(indexPath: IndexPath, completionHandler: @escaping (Bool) -> Void) -> UIAlertAction {
		let title = NSLocalizedString("Mark Older as Read", comment: "Mark Older as Read")
		let action = UIAlertAction(title: title, style: .default) { [weak self] action in
			self?.coordinator.markAsReadOlderArticlesInTimeline(indexPath)
			completionHandler(true)
		}
		return action
	}
	
	func discloseFeedAction(indexPath: IndexPath) -> UIAction? {
		guard let feed = coordinator.articles[indexPath.row].feed else {
			return nil
		}
		let title = NSLocalizedString("Select Feed", comment: "Select Feed")
		let action = UIAction(title: title, image: AppAssets.openInSidebarImage) { [weak self] action in
			self?.coordinator.discloseFeed(feed)
		}
		return action
	}
	
	func discloseFeedAlertAction(indexPath: IndexPath, completionHandler: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard let feed = coordinator.articles[indexPath.row].feed else {
			return nil
		}
		let title = NSLocalizedString("Select Feed", comment: "Select Feed")
		let action = UIAlertAction(title: title, style: .default) { [weak self] action in
			self?.coordinator.discloseFeed(feed)
			completionHandler(true)
		}
		return action
	}
	
	func markAllInFeedAsReadAction(indexPath: IndexPath) -> UIAction? {
		guard let feed = coordinator.articles[indexPath.row].feed else {
			return nil
		}
		
		let articles = Array(feed.fetchArticles())
		guard articles.canMarkAllAsRead() else {
			return nil
		}
		
		let localizedMenuText = NSLocalizedString("Mark All as Read in “%@”", comment: "Command")
		let title = NSString.localizedStringWithFormat(localizedMenuText as NSString, feed.nameForDisplay) as String
		
		let action = UIAction(title: title, image: AppAssets.markAllInFeedAsReadImage) { [weak self] action in
			self?.coordinator.markAllAsRead(articles)
		}
		return action
	}

	func markAllInFeedAsReadAlertAction(indexPath: IndexPath, completionHandler: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard let feed = coordinator.articles[indexPath.row].feed else {
			return nil
		}
		
		let articles = Array(feed.fetchArticles())
		guard articles.canMarkAllAsRead() else {
			return nil
		}
		
		let localizedMenuText = NSLocalizedString("Mark All as Read in “%@”", comment: "Mark All as Read in Feed")
		let title = NSString.localizedStringWithFormat(localizedMenuText as NSString, feed.nameForDisplay) as String
		
		let action = UIAlertAction(title: title, style: .default) { [weak self] action in
			self?.coordinator.markAllAsRead(articles)
			completionHandler(true)
		}
		return action
	}

	func openInBrowserAction(indexPath: IndexPath) -> UIAction? {
		guard let preferredLink = coordinator.articles[indexPath.row].preferredLink, let _ = URL(string: preferredLink) else {
			return nil
		}
		let title = NSLocalizedString("Open in Browser", comment: "Open in Browser")
		let action = UIAction(title: title, image: AppAssets.safariImage) { [weak self] action in
			self?.coordinator.showBrowser(for: indexPath)
		}
		return action
	}

	func openInBrowserAlertAction(indexPath: IndexPath, completionHandler: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard let preferredLink = coordinator.articles[indexPath.row].preferredLink, let _ = URL(string: preferredLink) else {
			return nil
		}
		let title = NSLocalizedString("Open in Browser", comment: "Open in Browser")
		let action = UIAlertAction(title: title, style: .default) { [weak self] action in
			self?.coordinator.showBrowser(for: indexPath)
			completionHandler(true)
		}
		return action
	}
	
	func shareDialogForTableCell(indexPath: IndexPath, url: URL, title: String?) {
		let itemSource = ArticleActivityItemSource(url: url, subject: title)
		let activityViewController = UIActivityViewController(activityItems: [itemSource], applicationActivities: nil)
		
		guard let cell = tableView.cellForRow(at: indexPath) else { return }
		let popoverController = activityViewController.popoverPresentationController
		popoverController?.sourceView = cell
		popoverController?.sourceRect = CGRect(x: 0, y: 0, width: cell.frame.size.width, height: cell.frame.size.height)
		
		present(activityViewController, animated: true)
	}
	
	func shareAction(indexPath: IndexPath) -> UIAction? {
		let article = coordinator.articles[indexPath.row]
		guard let preferredLink = article.preferredLink, let url = URL(string: preferredLink) else {
			return nil
		}
				
		let title = NSLocalizedString("Share", comment: "Share")
		let action = UIAction(title: title, image: AppAssets.shareImage) { [weak self] action in
			self?.shareDialogForTableCell(indexPath: indexPath, url: url, title: article.title)
		}
		return action
	}
	
	func shareAlertAction(indexPath: IndexPath, completionHandler: @escaping (Bool) -> Void) -> UIAlertAction? {
		let article = coordinator.articles[indexPath.row]
		guard let preferredLink = article.preferredLink, let url = URL(string: preferredLink) else {
			return nil
		}
		
		let title = NSLocalizedString("Share", comment: "Share")
		let action = UIAlertAction(title: title, style: .default) { [weak self] action in
			completionHandler(true)
			self?.shareDialogForTableCell(indexPath: indexPath, url: url, title: article.title)
		}
		return action
	}
	
}
