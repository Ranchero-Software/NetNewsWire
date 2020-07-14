//
//  ArticleViewController.swift
//  Multiplatform iOS
//
//  Created by Maurice Parker on 7/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit
import WebKit
import Account
import Articles
import SafariServices

class ArticleViewController: UIViewController {
	
	weak var sceneModel: SceneModel?
	
	private var pageViewController: UIPageViewController!
	
	private var currentWebViewController: WebViewController? {
		return pageViewController?.viewControllers?.first as? WebViewController
	}
	
	var articles: [Article]? {
		didSet {
			currentArticle = articles?.first
		}
	}
	
	var currentArticle: Article? {
		didSet {
			if let controller = currentWebViewController, controller.article != currentArticle {
				controller.setArticle(currentArticle)
				DispatchQueue.main.async {
					// You have to set the view controller to clear out the UIPageViewController child controller cache.
					// You also have to do it in an async call or you will get a strange assertion error.
					self.pageViewController.setViewControllers([controller], direction: .forward, animated: false, completion: nil)
				}
			}
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()

		pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: [:])
		pageViewController.delegate = self
		pageViewController.dataSource = self

		pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(pageViewController.view)
		addChild(pageViewController!)
		NSLayoutConstraint.activate([
			view.leadingAnchor.constraint(equalTo: pageViewController.view.leadingAnchor),
			view.trailingAnchor.constraint(equalTo: pageViewController.view.trailingAnchor),
			view.topAnchor.constraint(equalTo: pageViewController.view.topAnchor),
			view.bottomAnchor.constraint(equalTo: pageViewController.view.bottomAnchor)
		])
				
		let controller = createWebViewController(currentArticle, updateView: true)
		self.pageViewController.setViewControllers([controller], direction: .forward, animated: false, completion: nil)
	}
			
	// MARK: API

	func focus() {
		currentWebViewController?.focus()
	}

	func canScrollDown() -> Bool {
		return currentWebViewController?.canScrollDown() ?? false
	}

	func scrollPageDown() {
		currentWebViewController?.scrollPageDown()
	}
	
	func stopArticleExtractorIfProcessing() {
		currentWebViewController?.stopArticleExtractorIfProcessing()
	}

}


// MARK: WebViewControllerDelegate

extension ArticleViewController: WebViewControllerDelegate {
	
	func webViewController(_ webViewController: WebViewController, articleExtractorButtonStateDidUpdate buttonState: ArticleExtractorButtonState) {
		if webViewController === currentWebViewController {
//			articleExtractorButton.buttonState = buttonState
		}
	}
	
}

// MARK: UIPageViewControllerDataSource

extension ArticleViewController: UIPageViewControllerDataSource {
	
	func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
		guard let webViewController = viewController as? WebViewController,
			let currentArticle = webViewController.article,
			let article = sceneModel?.findPrevArticle(currentArticle) else {
			return nil
		}
		return createWebViewController(article)
	}
	
	func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
		guard let webViewController = viewController as? WebViewController,
			let currentArticle = webViewController.article,
			let article = sceneModel?.findNextArticle(currentArticle) else {
			return nil
		}
		return createWebViewController(article)
	}
	
}

// MARK: UIPageViewControllerDelegate

extension ArticleViewController: UIPageViewControllerDelegate {

	func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
		guard finished, completed else { return }
//		guard let article = currentWebViewController?.article else { return }
		
//		articleExtractorButton.buttonState = currentWebViewController?.articleExtractorButtonState ?? .off
		
		previousViewControllers.compactMap({ $0 as? WebViewController }).forEach({ $0.stopWebViewActivity() })
	}
	
}

// MARK: Private

private extension ArticleViewController {
	
	func createWebViewController(_ article: Article?, updateView: Bool = true) -> WebViewController {
		let controller = WebViewController()
		controller.sceneModel = sceneModel
		controller.delegate = self
		controller.setArticle(article, updateView: updateView)
		return controller
	}
	
	func resetWebViewController() {
		sceneModel?.webViewProvider?.flushQueue()
		sceneModel?.webViewProvider?.replenishQueueIfNeeded()
		if let controller = currentWebViewController {
			controller.fullReload()
			self.pageViewController.setViewControllers([controller], direction: .forward, animated: false, completion: nil)
		}
	}
	
}

public extension Notification.Name {
	static let FindInArticle = Notification.Name("FindInArticle")
	static let EndFindInArticle = Notification.Name("EndFindInArticle")
}
