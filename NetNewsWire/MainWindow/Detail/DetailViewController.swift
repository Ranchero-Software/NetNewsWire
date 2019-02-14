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
	case article(Article)
}

final class DetailViewController: NSViewController, WKUIDelegate {

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
		}
	}

	override func viewDidLoad() {
		currentWebViewController = regularWebViewController
	}

	// MARK: - API

	func showState(_ state: DetailState, mode: TimelineSourceMode) {
		// TODO: also to-do is caller
	}

	func canScrollDown(_ callback: @escaping (Bool) -> Void) {
		currentWebViewController.canScrollDown(callback)
	}

	override func scrollPageDown(_ sender: Any?) {
		currentWebViewController.scrollPageDown(sender)
	}
}

// MARK: - DetailWebViewControllerDelegate

extension DetailViewController: DetailWebViewControllerDelegate {

	func mouseDidEnter(_ link: String) {
		guard !link.isEmpty else {
			return
		}
		statusBarView.mouseoverLink = link
	}

	func mouseDidExit(_ link: String) {
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
}
