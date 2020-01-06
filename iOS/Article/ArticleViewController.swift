//
//  ArticleViewController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import WebKit
import Account
import Articles
import SafariServices

class ArticleViewController: UIViewController {
	
	@IBOutlet private weak var nextUnreadBarButtonItem: UIBarButtonItem!
	@IBOutlet private weak var prevArticleBarButtonItem: UIBarButtonItem!
	@IBOutlet private weak var nextArticleBarButtonItem: UIBarButtonItem!
	@IBOutlet private weak var readBarButtonItem: UIBarButtonItem!
	@IBOutlet private weak var starBarButtonItem: UIBarButtonItem!
	@IBOutlet private weak var actionBarButtonItem: UIBarButtonItem!
	
	private var pageViewController: UIPageViewController!
	
	private var currentWebViewController: WebViewController? {
		return pageViewController?.viewControllers?.first as? WebViewController
	}
	
	private var articleExtractorButton: ArticleExtractorButton = {
		let button = ArticleExtractorButton(type: .system)
		button.frame = CGRect(x: 0, y: 0, width: 44.0, height: 44.0)
		button.setImage(AppAssets.articleExtractorOff, for: .normal)
		return button
	}()
	
	private var isFullScreenAvailable: Bool {
		return traitCollection.userInterfaceIdiom == .phone && coordinator.isRootSplitCollapsed
	}

	weak var coordinator: SceneCoordinator!
	
	var article: Article? {
		didSet {
			if let controller = currentWebViewController, controller.article != article {
				controller.article = article
				DispatchQueue.main.async {
					// You have to set the view controller to clear out the UIPageViewController child controller cache.
					// You also have to do it in an async call or you will get a strange assertion error.
					self.pageViewController.setViewControllers([controller], direction: .forward, animated: false, completion: nil)
				}
			}
			updateUI()
		}
	}
	
	private let keyboardManager = KeyboardManager(type: .detail)
	override var keyCommands: [UIKeyCommand]? {
		return keyboardManager.keyCommands
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(statusesDidChange(_:)), name: .StatusesDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)

		let fullScreenTapZone = UIView()
		NSLayoutConstraint.activate([
			fullScreenTapZone.widthAnchor.constraint(equalToConstant: 150),
			fullScreenTapZone.heightAnchor.constraint(equalToConstant: 44)
		])
		fullScreenTapZone.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapNavigationBar)))
		navigationItem.titleView = fullScreenTapZone
		
		articleExtractorButton.addTarget(self, action: #selector(toggleArticleExtractor(_:)), for: .touchUpInside)
		toolbarItems?.insert(UIBarButtonItem(customView: articleExtractorButton), at: 6)

		pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: [:])
		pageViewController.delegate = self
		pageViewController.dataSource = self
		
		view.addSubview(pageViewController.view)
		addChild(pageViewController!)
		NSLayoutConstraint.activate([
			view.leadingAnchor.constraint(equalTo: pageViewController.view.leadingAnchor),
			view.trailingAnchor.constraint(equalTo: pageViewController.view.trailingAnchor),
			view.topAnchor.constraint(equalTo: pageViewController.view.topAnchor),
			view.bottomAnchor.constraint(equalTo: pageViewController.view.bottomAnchor)
		])
				
		let controller = createWebViewController(article)
		pageViewController.setViewControllers([controller], direction: .forward, animated: false, completion: nil)
		
		updateUI()
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		if AppDefaults.articleFullscreenEnabled {
			currentWebViewController?.hideBars()
		}
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(true)
		coordinator.isArticleViewControllerPending = false
	}
	
	override func viewSafeAreaInsetsDidChange() {
		// This will animate if the show/hide bars animation is happening.
		view.layoutIfNeeded()
	}
	
	func updateUI() {
		
		guard let article = article else {
			articleExtractorButton.isEnabled = false
			nextUnreadBarButtonItem.isEnabled = false
			prevArticleBarButtonItem.isEnabled = false
			nextArticleBarButtonItem.isEnabled = false
			readBarButtonItem.isEnabled = false
			starBarButtonItem.isEnabled = false
			actionBarButtonItem.isEnabled = false
			return
		}
		
		nextUnreadBarButtonItem.isEnabled = coordinator.isAnyUnreadAvailable
		prevArticleBarButtonItem.isEnabled = coordinator.isPrevArticleAvailable
		nextArticleBarButtonItem.isEnabled = coordinator.isNextArticleAvailable

		articleExtractorButton.isEnabled = true
		readBarButtonItem.isEnabled = true
		starBarButtonItem.isEnabled = true
		actionBarButtonItem.isEnabled = true

		let readImage = article.status.read ? AppAssets.circleOpenImage : AppAssets.circleClosedImage
		readBarButtonItem.image = readImage
		
		let starImage = article.status.starred ? AppAssets.starClosedImage : AppAssets.starOpenImage
		starBarButtonItem.image = starImage
		
	}
	
	// MARK: Notifications
	
	@objc dynamic func unreadCountDidChange(_ notification: Notification) {
		updateUI()
	}
	
	@objc func statusesDidChange(_ note: Notification) {
		guard let articleIDs = note.userInfo?[Account.UserInfoKey.articleIDs] as? Set<String> else {
			return
		}
		guard let article = article else {
			return
		}
		if articleIDs.contains(article.articleID) {
			updateUI()
		}
	}

	@objc func willEnterForeground(_ note: Notification) {
		// The toolbar will come back on you if you don't hide it again
		if AppDefaults.articleFullscreenEnabled {
			currentWebViewController?.hideBars()
		}
	}
	
	// MARK: Actions

	@objc func didTapNavigationBar() {
		currentWebViewController?.hideBars()
	}

	@objc func showBars(_ sender: Any) {
		currentWebViewController?.showBars()
	}

	@IBAction func toggleArticleExtractor(_ sender: Any) {
		currentWebViewController?.toggleArticleExtractor()
	}
	
	@IBAction func nextUnread(_ sender: Any) {
		coordinator.selectNextUnread()
	}
	
	@IBAction func prevArticle(_ sender: Any) {
		coordinator.selectPrevArticle()
	}
	
	@IBAction func nextArticle(_ sender: Any) {
		coordinator.selectNextArticle()
	}
	
	@IBAction func toggleRead(_ sender: Any) {
		coordinator.toggleReadForCurrentArticle()
	}
	
	@IBAction func toggleStar(_ sender: Any) {
		coordinator.toggleStarredForCurrentArticle()
	}
	
	@IBAction func showActivityDialog(_ sender: Any) {
		currentWebViewController?.showActivityDialog(popOverBarButtonItem: actionBarButtonItem)
	}
	
	// MARK: Keyboard Shortcuts
	@objc func navigateToTimeline(_ sender: Any?) {
		coordinator.navigateToTimeline()
	}
	
	// MARK: API

	func focus() {
		currentWebViewController?.focus()
	}

	func finalScrollPosition() -> CGFloat {
		return currentWebViewController?.finalScrollPosition() ?? 0.0
	}
	
	func canScrollDown() -> Bool {
		return currentWebViewController?.canScrollDown() ?? false
	}

	func scrollPageDown() {
		currentWebViewController?.scrollPageDown()
	}
	
	func fullReload() {
		currentWebViewController?.fullReload()
	}
	
}

// MARK: WebViewControllerDelegate

extension ArticleViewController: WebViewControllerDelegate {
	func webViewController(_ webViewController: WebViewController, articleExtractorButtonStateDidUpdate buttonState: ArticleExtractorButtonState) {
		if webViewController === currentWebViewController {
			articleExtractorButton.buttonState = buttonState
		}
	}
	
}

// MARK: UIPageViewControllerDataSource

extension ArticleViewController: UIPageViewControllerDataSource {
	
	func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
		guard let article = coordinator.prevArticle else {
			return nil
		}
		return createWebViewController(article)
	}
	
	func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
		guard let article = coordinator.nextArticle else {
			return nil
		}
		return createWebViewController(article)
	}
	
}

// MARK: UIPageViewControllerDelegate

extension ArticleViewController: UIPageViewControllerDelegate {

	func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
		guard finished, completed else { return }
		guard let article = currentWebViewController?.article else { return }
		coordinator.selectArticle(article)
		articleExtractorButton.buttonState = currentWebViewController?.articleExtractorButtonState ?? .off
	}
	
}

// MARK: Private

private extension ArticleViewController {
	
	func createWebViewController(_ article: Article?) -> WebViewController {
		let controller = WebViewController()
		controller.coordinator = coordinator
		controller.delegate = self
		controller.article = article
		return controller
	}
	
}
