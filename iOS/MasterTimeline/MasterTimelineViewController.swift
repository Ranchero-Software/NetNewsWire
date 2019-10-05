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

	private var titleView: MasterTimelineTitleView?
	private var numberOfTextLines = 0
	
	@IBOutlet weak var markAllAsReadButton: UIBarButtonItem!
	@IBOutlet weak var firstUnreadButton: UIBarButtonItem!
	
	private lazy var dataSource = makeDataSource()
	private let searchController = UISearchController(searchResultsController: nil)
	
	weak var coordinator: SceneCoordinator!
	var undoableCommands = [UndoableCommand]()

	private let keyboardManager = KeyboardManager(type: .timeline)
	override var keyCommands: [UIKeyCommand]? {
		return keyboardManager.keyCommands
	}
	
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
		NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange), name: .DisplayNameDidChange, object: nil)


		// Setup the Search Controller
		searchController.delegate = self
		searchController.searchResultsUpdater = self
		searchController.obscuresBackgroundDuringPresentation = false
		searchController.searchBar.delegate = self
		searchController.searchBar.placeholder = NSLocalizedString("Search Articles", comment: "Search Articles")
		searchController.searchBar.scopeButtonTitles = [
			NSLocalizedString("Here", comment: "Here"),
			NSLocalizedString("All Articles", comment: "All Articles")
		]
		navigationItem.searchController = searchController
		definesPresentationContext = true

		// Setup the Refresh Control
		refreshControl = UIRefreshControl()
		refreshControl!.addTarget(self, action: #selector(refreshAccounts(_:)), for: .valueChanged)
		
		// Configure the table
		tableView.dataSource = dataSource
		numberOfTextLines = AppDefaults.timelineNumberOfLines
		resetEstimatedRowHeight()
		
		resetUI()
		
	}
	
	override func viewWillAppear(_ animated: Bool) {
		clearsSelectionOnViewWillAppear = coordinator.isRootSplitCollapsed
		applyChanges(animate: false)
		super.viewWillAppear(animated)
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		updateProgressIndicatorIfNeeded()
	}
	
	// MARK: Actions

	@IBAction func markAllAsRead(_ sender: Any) {
		if coordinator.askBeforeMarkAllAsRead {
			let alertController = MarkArticlesReadAlertController.timelineArticlesAlert { [weak self] _ in
				self?.coordinator.markAllAsReadInTimeline()
			}
			
			present(alertController, animated: true)
		} else {
			coordinator.markAllAsReadInTimeline()
		}
	}
	
	@IBAction func firstUnread(_ sender: Any) {
		coordinator.selectNextUnread()
	}
	
	// MARK: Keyboard shortcuts
	
	@objc func selectNextUp(_ sender: Any?) {
		coordinator.selectPrevArticle()
	}

	@objc func selectNextDown(_ sender: Any?) {
		coordinator.selectNextArticle()
	}

	@objc func navigateToSidebar(_ sender: Any?) {
		coordinator.navigateToFeeds()
	}
	
	@objc func navigateToDetail(_ sender: Any?) {
		coordinator.navigateToDetail()
	}
	
	@objc func showFeedInspector(_ sender: UITapGestureRecognizer) {
		coordinator.showFeedInspector()
	}
	
	// MARK: API
	
	func restoreSelectionIfNecessary(adjustScroll: Bool) {
		if let article = coordinator.currentArticle, let indexPath = dataSource.indexPath(for: article) {
			if adjustScroll {
				tableView.selectRowAndScrollIfNotVisible(at: indexPath, animated: false, deselect: coordinator.isRootSplitCollapsed)
			} else {
				tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
			}
		}
	}

	func reinitializeArticles() {
		resetUI()
	}
	
	func reloadArticles(animate: Bool) {
		applyChanges(animate: animate)
	}
	
	func updateArticleSelection(animate: Bool) {
		if let article = coordinator.currentArticle, let indexPath = dataSource.indexPath(for: article) {
			if tableView.indexPathForSelectedRow != indexPath {
				tableView.selectRowAndScrollIfNotVisible(at: indexPath, animated: true, deselect: coordinator.isRootSplitCollapsed)
			}
		} else {
			tableView.selectRow(at: nil, animated: animate, scrollPosition: .none)
		}
		
		updateUI()
	}

	func showSearchAll() {
		navigationItem.searchController?.isActive = true
		navigationItem.searchController?.searchBar.selectedScopeButtonIndex = 1
		navigationItem.searchController?.searchBar.becomeFirstResponder()
	}
	
	func focus() {
		becomeFirstResponder()
	}

	// MARK: - Table view

	override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		guard let article = dataSource.itemIdentifier(for: indexPath) else { return nil }
		
		// Set up the read action
		let readTitle = article.status.read ?
			NSLocalizedString("Unread", comment: "Unread") :
			NSLocalizedString("Read", comment: "Read")
		
		let readAction = UIContextualAction(style: .normal, title: readTitle) { [weak self] (action, view, completionHandler) in
			self?.coordinator.toggleRead(article)
			completionHandler(true)
		}
		
		readAction.image = article.status.read ? AppAssets.circleClosedImage : AppAssets.circleOpenImage
		readAction.backgroundColor = AppAssets.primaryAccentColor
		
		return UISwipeActionsConfiguration(actions: [readAction])
	}
	
	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		
		guard let article = dataSource.itemIdentifier(for: indexPath) else { return nil }
		
		// Set up the star action
		let starTitle = article.status.starred ?
			NSLocalizedString("Unstar", comment: "Unstar") :
			NSLocalizedString("Star", comment: "Star")
		
		let starAction = UIContextualAction(style: .normal, title: starTitle) { [weak self] (action, view, completionHandler) in
			self?.coordinator.toggleStar(article)
			completionHandler(true)
		}
		
		starAction.image = article.status.starred ? AppAssets.starOpenImage : AppAssets.starClosedImage
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
				
				alert.addAction(self.markOlderAsReadAlertAction(article, completionHandler: completionHandler))
				
				if let action = self.discloseFeedAlertAction(article, completionHandler: completionHandler) {
					alert.addAction(action)
				}
				
				if let action = self.markAllInFeedAsReadAlertAction(article, completionHandler: completionHandler) {
					alert.addAction(action)
				}

				if let action = self.openInBrowserAlertAction(article, completionHandler: completionHandler) {
					alert.addAction(action)
				}

				if let action = self.shareAlertAction(article, indexPath: indexPath, completionHandler: completionHandler) {
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

		return UISwipeActionsConfiguration(actions: [starAction, moreAction])
		
	}

	override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {

		guard let article = dataSource.itemIdentifier(for: indexPath) else { return nil }
		
		return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { [weak self] suggestedActions in

			guard let self = self else { return nil }
			
			var actions = [UIAction]()
			actions.append(self.toggleArticleReadStatusAction(article))
			actions.append(self.toggleArticleStarStatusAction(article))
			actions.append(self.markOlderAsReadAction(article))
			
			if let action = self.discloseFeedAction(article) {
				actions.append(action)
			}
			
			if let action = self.markAllInFeedAsReadAction(article) {
				actions.append(action)
			}
			
			if let action = self.openInBrowserAction(article) {
				actions.append(action)
			}
			
			if let action = self.shareAction(article, indexPath: indexPath) {
				actions.append(action)
			}
			
			return UIMenu(title: "", children: actions)

		})
		
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		becomeFirstResponder()
		let article = dataSource.itemIdentifier(for: indexPath)
		coordinator.selectArticle(article, automated: false)
	}
	
	// MARK: Notifications

	@objc dynamic func unreadCountDidChange(_ notification: Notification) {
		updateUI()
	}
	
	@objc func statusesDidChange(_ note: Notification) {
		guard let updatedArticles = note.userInfo?[Account.UserInfoKey.articles] as? Set<Article> else {
			return
		}
		
		let visibleArticles = tableView.indexPathsForVisibleRows!.compactMap { return dataSource.itemIdentifier(for: $0) }
		let visibleUpdatedArticles = visibleArticles.filter { updatedArticles.contains($0) }

		for article in visibleUpdatedArticles {
			if let indexPath = dataSource.indexPath(for: article) {
				if let cell = tableView.cellForRow(at: indexPath) as? MasterTimelineTableViewCell {
					configure(cell, article: article)
				}
			}
		}
	}

	@objc func feedIconDidBecomeAvailable(_ note: Notification) {
		guard let feed = note.userInfo?[UserInfoKey.feed] as? Feed else {
			return
		}
		tableView.indexPathsForVisibleRows?.forEach { indexPath in
			guard let article = dataSource.itemIdentifier(for: indexPath) else {
				return
			}
			if article.feed == feed, let cell = tableView.cellForRow(at: indexPath) as? MasterTimelineTableViewCell, let image = avatarFor(article) {
				cell.setAvatarImage(image)
			}
		}
	}

	@objc func avatarDidBecomeAvailable(_ note: Notification) {
		guard coordinator.showAvatars, let avatarURL = note.userInfo?[UserInfoKey.url] as? String else {
			return
		}
		tableView.indexPathsForVisibleRows?.forEach { indexPath in
			guard let article = dataSource.itemIdentifier(for: indexPath), let authors = article.authors, !authors.isEmpty else {
				return
			}
			for author in authors {
				if author.avatarURL == avatarURL, let cell = tableView.cellForRow(at: indexPath) as? MasterTimelineTableViewCell, let image = avatarFor(article) {
					cell.setAvatarImage(image)
				}
			}
		}
	}

	@objc func faviconDidBecomeAvailable(_ note: Notification) {
		titleView?.imageView.image = coordinator.timelineFavicon
		if coordinator.showAvatars {
			queueReloadAvailableCells()
		}
	}

	@objc func userDefaultsDidChange(_ note: Notification) {
		if numberOfTextLines != AppDefaults.timelineNumberOfLines {
			numberOfTextLines = AppDefaults.timelineNumberOfLines
			resetEstimatedRowHeight()
			reloadAllVisibleCells()
		}
	}
	
	@objc func contentSizeCategoryDidChange(_ note: Notification) {
		reloadAllVisibleCells()
	}
	
	@objc func progressDidChange(_ note: Notification) {
		updateProgressIndicatorIfNeeded()
	}
	
	@objc func displayNameDidChange(_ note: Notification) {
		titleView?.label.text = coordinator.timelineName
	}
	
	// MARK: Reloading
	
	func queueReloadAvailableCells() {
		CoalescingQueue.standard.add(self, #selector(reloadAllVisibleCells))
	}

	@objc private func reloadAllVisibleCells() {
		let visibleArticles = tableView.indexPathsForVisibleRows!.compactMap { return dataSource.itemIdentifier(for: $0) }
		reloadCells(visibleArticles)
	}
	
	private func reloadCells(_ articles: [Article]) {
		var snapshot = dataSource.snapshot()
		snapshot.reloadItems(articles)
		dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
			self?.restoreSelectionIfNecessary(adjustScroll: false)
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

// MARK: Searching

extension MasterTimelineViewController: UISearchControllerDelegate {

	func willPresentSearchController(_ searchController: UISearchController) {
		coordinator.beginSearching()
		searchController.searchBar.showsScopeBar = true
	}

	func willDismissSearchController(_ searchController: UISearchController) {
		coordinator.endSearching()
		searchController.searchBar.showsScopeBar = false
	}

}

extension MasterTimelineViewController: UISearchResultsUpdating {

	func updateSearchResults(for searchController: UISearchController) {
		let searchScope = SearchScope(rawValue: searchController.searchBar.selectedScopeButtonIndex)!
		coordinator.searchArticles(searchController.searchBar.text!, searchScope)
	}

}

extension MasterTimelineViewController: UISearchBarDelegate {
	func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
		let searchScope = SearchScope(rawValue: selectedScope)!
		coordinator.searchArticles(searchBar.text!, searchScope)
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
		
		if let titleView = Bundle.main.loadNibNamed("MasterTimelineTitleView", owner: self, options: nil)?[0] as? MasterTimelineTitleView {
			self.titleView = titleView
			
			titleView.imageView.image = coordinator.timelineFavicon
			if traitCollection.userInterfaceStyle == .dark && titleView.imageView.image?.isDark() ?? false {
				titleView.imageView.backgroundColor = AppAssets.avatarBackgroundColor
			}
			
			titleView.label.text = coordinator.timelineName
			updateTitleUnreadCount()

			if coordinator.timelineFetcher is Feed {
				titleView.heightAnchor.constraint(equalToConstant: 44.0).isActive = true
				let tap = UITapGestureRecognizer(target: self, action:#selector(showFeedInspector(_:)))
				titleView.addGestureRecognizer(tap)
			}
			
			navigationItem.titleView = titleView
		}

		
		tableView.selectRow(at: nil, animated: false, scrollPosition: .top)
		if dataSource.snapshot().itemIdentifiers(inSection: 0).count > 0 {
			tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
		}
		
		updateUI()
		
	}
	
	func updateUI() {
		updateTitleUnreadCount()
		markAllAsReadButton.isEnabled = coordinator.isTimelineUnreadAvailable
		firstUnreadButton.isEnabled = coordinator.isTimelineUnreadAvailable
	}
	
	func updateTitleUnreadCount() {
		if let unreadCountProvider = coordinator.timelineFetcher as? UnreadCountProvider {
			UIView.animate(withDuration: 0.3) {
				self.titleView?.unreadCountView.unreadCount = unreadCountProvider.unreadCount
				self.titleView?.setNeedsLayout()
				self.titleView?.layoutIfNeeded()
			}
		}
	}
	
	func updateProgressIndicatorIfNeeded() {
		if !coordinator.isThreePanelMode {
			navigationController?.updateAccountRefreshProgressIndicator()
		}
	}

	func applyChanges(animate: Bool, completion: (() -> Void)? = nil) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, Article>()
		snapshot.appendSections([0])
		snapshot.appendItems(coordinator.articles, toSection: 0)
        
		dataSource.apply(snapshot, animatingDifferences: animate) { [weak self] in
			self?.restoreSelectionIfNecessary(adjustScroll: false)
			completion?()
		}
	}
	
	func makeDataSource() -> UITableViewDiffableDataSource<Int, Article> {
		return MasterTimelineDataSource(coordinator: coordinator, tableView: tableView, cellProvider: { [weak self] tableView, indexPath, article in
			let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! MasterTimelineTableViewCell
			self?.configure(cell, article: article)
			return cell
		})
    }
	
	func configure(_ cell: MasterTimelineTableViewCell, article: Article) {
		
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
	
	func toggleArticleReadStatusAction(_ article: Article) -> UIAction {

		let title = article.status.read ?
			NSLocalizedString("Mark as Unread", comment: "Mark as Unread") :
			NSLocalizedString("Mark as Read", comment: "Mark as Read")
		let image = article.status.read ? AppAssets.circleClosedImage : AppAssets.circleOpenImage

		let action = UIAction(title: title, image: image) { [weak self] action in
			self?.coordinator.toggleRead(article)
		}
		
		return action
	}
	
	func toggleArticleStarStatusAction(_ article: Article) -> UIAction {

		let title = article.status.starred ?
			NSLocalizedString("Mark as Unstarred", comment: "Mark as Unstarred") :
			NSLocalizedString("Mark as Starred", comment: "Mark as Starred")
		let image = article.status.starred ? AppAssets.starOpenImage : AppAssets.starClosedImage

		let action = UIAction(title: title, image: image) { [weak self] action in
			self?.coordinator.toggleStar(article)
		}
		
		return action
	}
	
	func markOlderAsReadAction(_ article: Article) -> UIAction {
		let title = NSLocalizedString("Mark Older as Read", comment: "Mark Older as Read")
		let image = coordinator.sortDirection == .orderedDescending ? AppAssets.markOlderAsReadDownImage : AppAssets.markOlderAsReadUpImage
		let action = UIAction(title: title, image: image) { [weak self] action in
			self?.coordinator.markAsReadOlderArticlesInTimeline(article)
		}
		return action
	}
	
	func markOlderAsReadAlertAction(_ article: Article, completionHandler: @escaping (Bool) -> Void) -> UIAlertAction {
		let title = NSLocalizedString("Mark Older as Read", comment: "Mark Older as Read")
		let action = UIAlertAction(title: title, style: .default) { [weak self] action in
			self?.coordinator.markAsReadOlderArticlesInTimeline(article)
			completionHandler(true)
		}
		return action
	}
	
	func discloseFeedAction(_ article: Article) -> UIAction? {
		guard let feed = article.feed else { return nil }
		
		let title = NSLocalizedString("Select Feed", comment: "Select Feed")
		let action = UIAction(title: title, image: AppAssets.openInSidebarImage) { [weak self] action in
			self?.coordinator.discloseFeed(feed)
		}
		return action
	}
	
	func discloseFeedAlertAction(_ article: Article, completionHandler: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard let feed = article.feed else { return nil }

		let title = NSLocalizedString("Select Feed", comment: "Select Feed")
		let action = UIAlertAction(title: title, style: .default) { [weak self] action in
			self?.coordinator.discloseFeed(feed)
			completionHandler(true)
		}
		return action
	}
	
	func markAllInFeedAsReadAction(_ article: Article) -> UIAction? {
		guard let feed = article.feed else { return nil }

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

	func markAllInFeedAsReadAlertAction(_ article: Article, completionHandler: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard let feed = article.feed else { return nil }

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

	func openInBrowserAction(_ article: Article) -> UIAction? {
		guard let preferredLink = article.preferredLink, let _ = URL(string: preferredLink) else {
			return nil
		}
		let title = NSLocalizedString("Open in Browser", comment: "Open in Browser")
		let action = UIAction(title: title, image: AppAssets.safariImage) { [weak self] action in
			self?.coordinator.showBrowserForArticle(article)
		}
		return action
	}

	func openInBrowserAlertAction(_ article: Article, completionHandler: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard let preferredLink = article.preferredLink, let _ = URL(string: preferredLink) else {
			return nil
		}
		let title = NSLocalizedString("Open in Browser", comment: "Open in Browser")
		let action = UIAlertAction(title: title, style: .default) { [weak self] action in
			self?.coordinator.showBrowserForArticle(article)
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
	
	func shareAction(_ article: Article, indexPath: IndexPath) -> UIAction? {
		guard let preferredLink = article.preferredLink, let url = URL(string: preferredLink) else {
			return nil
		}
				
		let title = NSLocalizedString("Share", comment: "Share")
		let action = UIAction(title: title, image: AppAssets.shareImage) { [weak self] action in
			self?.shareDialogForTableCell(indexPath: indexPath, url: url, title: article.title)
		}
		return action
	}
	
	func shareAlertAction(_ article: Article, indexPath: IndexPath, completionHandler: @escaping (Bool) -> Void) -> UIAlertAction? {
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
