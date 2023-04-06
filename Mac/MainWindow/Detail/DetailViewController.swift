//
//  DetailViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/26/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import WebKit
import RSCore
import Articles
import RSWeb

enum DetailState: Equatable {
	case noSelection
	case multipleSelection
	case loading
	case article(Article, CGFloat?)
	case extracted(Article, ExtractedArticle, CGFloat?)
}

@MainActor final class DetailViewController: NSViewController, WKUIDelegate {

	@IBOutlet var containerView: DetailContainerView!
	@IBOutlet var statusBarView: DetailStatusBarView!

	lazy var regularWebViewController = {
		return createWebViewController()
	}()

	lazy var searchWebViewController = {
		return createWebViewController()
	}()

	var currentWebViewController: DetailWebViewController! {
		didSet {
			let webview = currentWebViewController.view
			if containerView.contentView === webview {
				return
			}
			statusBarView.mouseoverLink = nil
			containerView.contentView = webview
			resetTextFinder()
		}
	}

	override func viewDidLoad() {
		currentWebViewController = regularWebViewController
	}

	// MARK: - API

	func setState(_ state: DetailState, mode: TimelineSourceMode) {
		webViewController(for: mode).state = state
		resetTextFinder()
	}

	func showDetail(for mode: TimelineSourceMode) {
		currentWebViewController = webViewController(for: mode)
	}

	func stopMediaPlayback() {
		currentWebViewController.stopMediaPlayback()
	}
	
	func canScrollDown(_ callback: @escaping (Bool) -> Void) {
		currentWebViewController.canScrollDown(callback)
	}

	func canScrollUp(_ callback: @escaping (Bool) -> Void) {
		currentWebViewController.canScrollUp(callback)
	}

	override func scrollPageDown(_ sender: Any?) {
		currentWebViewController.scrollPageDown(sender)
	}

	override func scrollPageUp(_ sender: Any?) {
		currentWebViewController.scrollPageUp(sender)
	}
	
	// MARK: - Navigation
	
	func focus() {
		guard let window = currentWebViewController.webView.window else {
			return
		}
		window.makeFirstResponderUnlessDescendantIsFirstResponder(currentWebViewController.webView)
	}
	
	// MARK: State Restoration
	
	func saveState(to state: inout [AnyHashable : Any]) {
		currentWebViewController.saveState(to: &state)
	}

	// MARK: Find in Article

	private var didLoadTextFinder = false
	lazy private var textFinder: NSTextFinder = {
		let finder = NSTextFinder()
		finder.isIncrementalSearchingEnabled = true
		finder.incrementalSearchingShouldDimContentView = false
		finder.client = self.currentWebViewController.webView
		finder.findBarContainer = self.containerView
		didLoadTextFinder = true
		return finder
	}()

	private func resetTextFinder() {
		if didLoadTextFinder {
			self.textFinder.performAction(.hideFindInterface)
			self.textFinder.client = currentWebViewController.webView
		}
	}

	@IBAction func performFindPanelAction(_ sender: Any?) {
		if let menuItem = sender as? NSMenuItem, let findAction = NSTextFinder.Action(rawValue: menuItem.tag) {
			self.textFinder.performAction(findAction)
		}
	}

}

// MARK: - DetailWebViewControllerDelegate

extension DetailViewController: DetailWebViewControllerDelegate {

	func mouseDidEnter(_ detailWebViewController: DetailWebViewController, link: String) {
		guard !link.isEmpty, detailWebViewController === currentWebViewController else {
			return
		}
		statusBarView.mouseoverLink = link
	}

	func mouseDidExit(_ detailWebViewController: DetailWebViewController) {
		guard detailWebViewController === currentWebViewController else {
			return
		}
		statusBarView.mouseoverLink = nil
	}
}

// MARK: - Private

private extension DetailViewController {

	func createWebViewController() -> DetailWebViewController {
		let controller = DetailWebViewController()
		controller.delegate = self
		controller.state = .noSelection
		return controller
	}

	func webViewController(for mode: TimelineSourceMode) -> DetailWebViewController {
		switch mode {
		case .regular:
			return regularWebViewController
		case .search:
			return searchWebViewController
		}
	}
}
