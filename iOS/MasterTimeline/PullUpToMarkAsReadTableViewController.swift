//
//  PullUpToMarkAsReadTableViewController.swift
//  NetNewsWire-iOS
//
//  Created by Rob Everhardt on 17-11-2021.
//  Copyright © 2021 Ranchero Software. All rights reserved.
//

import UIKit


class PullUpToMarkAsReadTableViewController: UITableViewController {
	private let textPull = "Pull up to mark as read"
	private let textRelease = "Release to mark as read"
	private let textMarkingAsRead = "Marking as read..."
	private let pullUpToMarkAsReadFooterHeight = 52.0

	public var isMarkingAsRead = false
	public var isDragging = false
	
	private var textLabel: UILabel?
	private var markAsReadFooterView: UIView?

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		addPullUpToMarkAsReadFooter()
	}

	func addPullUpToMarkAsReadFooter() {
		let footerView = UIView.init(frame: CGRect(
			x: 0.0,
			y: view.frame.size.height - view.safeAreaInsets.bottom - pullUpToMarkAsReadFooterHeight,
			width: view.frame.size.width,
			height: pullUpToMarkAsReadFooterHeight
		))
		footerView.isHidden = true
		footerView.backgroundColor = UIColor.clear

		let label = UILabel.init(frame: CGRect(
			x: 0.0,
			y: 0.0,
			width: view.frame.size.width,
			height: pullUpToMarkAsReadFooterHeight
		))
		label.backgroundColor = UIColor.clear
		label.font = UIFont.boldSystemFont(ofSize: 12)
		label.textAlignment = NSTextAlignment.center
		
		textLabel = label
		footerView.addSubview(label)
		
		let backgroundView = UIView()
		backgroundView.addSubview(footerView)
		self.tableView.backgroundView = backgroundView
		self.markAsReadFooterView = footerView
	}
	
	override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
		if (!AppDefaults.shared.markArticlesAsReadOnScroll || isMarkingAsRead) {
			return
		}
		if let footerView = markAsReadFooterView {
			footerView.isHidden = false
		}
		isDragging = true
	}

	override func scrollViewDidScroll(_ scrollView: UIScrollView) {
		guard AppDefaults.shared.markArticlesAsReadOnScroll, let label = textLabel else {
			return
		}
		let visibleHeight = view.frame.size.height -
			view.safeAreaInsets.top
			- view.safeAreaInsets.bottom
		let currentOffset = scrollView.contentOffset.y + view.safeAreaInsets.top
		let scrolledOutOfViewWhenBottomIsReached = max(scrollView.contentSize.height - visibleHeight,0)
		let pullUpVisibleHeight = max(currentOffset - scrolledOutOfViewWhenBottomIsReached,0)
		
		if (isMarkingAsRead) {
			// Update the content inset, good for section headers
			if (pullUpVisibleHeight < pullUpToMarkAsReadFooterHeight) {
				self.tableView.contentInset = UIEdgeInsets.init(
					top: 0,
					left: 0,
					bottom: pullUpVisibleHeight,
					right: 0
				);
			}
		} else if (isDragging) {
			// Update the label
			UIView.animate(withDuration: 0.25) {
				if (pullUpVisibleHeight > self.pullUpToMarkAsReadFooterHeight) {
					// User is scrolling above the header
					label.text = self.textRelease;
				} else {
					// User is scrolling somewhere within the header
					label.text = self.textPull;
				}
			}
		}
	}
	
	override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
		if (!AppDefaults.shared.markArticlesAsReadOnScroll || isMarkingAsRead) {
			return
		}
		isDragging = false
		
		let visibleHeight = view.frame.size.height -
			view.safeAreaInsets.top
			- view.safeAreaInsets.bottom
		let currentOffset = scrollView.contentOffset.y + view.safeAreaInsets.top
		let scrolledOutOfViewWhenBottomIsReached = max(scrollView.contentSize.height - visibleHeight,0)
		let pullUpVisibleHeight = max(currentOffset - scrolledOutOfViewWhenBottomIsReached,0)
		
		if (pullUpVisibleHeight > pullUpToMarkAsReadFooterHeight) {
			startMarkingAsRead()
		} else {
			if let footerView = markAsReadFooterView {
				footerView.isHidden = true
			}
		}
	}
	
	func startMarkingAsRead() {
		isMarkingAsRead = true
		UIView.animate(withDuration: 0.25) {
			self.tableView.contentInset =  UIEdgeInsets.init(
				top: 0,
				left: 0,
				bottom: self.pullUpToMarkAsReadFooterHeight,
				right: 0
			);
			if let label = self.textLabel {
				label.text = self.textMarkingAsRead
			}
		}
		
		pulledUpToMarkAsRead()
	}

	func stopMarkingAsRead() {
		isMarkingAsRead = false
		if let label = textLabel {
			label.text = textPull
		}
		self.tableView.contentInset = UIEdgeInsets.zero
		if let footerView = markAsReadFooterView {
			footerView.isHidden = true
		}
	}
	
	func pulledUpToMarkAsRead() {
		// to override by implementation, which should also call stopMarkingAsRead when done or call this

		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			self.stopMarkingAsRead()
		}
	}
}
