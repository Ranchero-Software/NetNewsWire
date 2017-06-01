//
//  MainWindowController.swift
//  Evergreen
//
//  Created by Brent Simmons on 8/1/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Cocoa
import DataModel

private let kWindowFrameKey = "MainWindow"

class MainWindowController : NSWindowController, NSUserInterfaceValidations {
    
    // MARK: NSWindowController

    override func windowDidLoad() {
        
        super.windowDidLoad()
        
//		window?.titleVisibility = .hidden
		window?.setFrameUsingName(kWindowFrameKey, force: true)
		
		detailSplitViewItem?.minimumThickness = 384
		
		NotificationCenter.default.addObserver(self, selector: #selector(applicationWillTerminate(_:)), name: .NSApplicationWillTerminate, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(appNavigationKeyPressed(_:)), name: .AppNavigationKeyPressed, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(refreshProgressDidChange(_:)), name: .AccountRefreshProgressDidChange, object: nil)
		}
	
    // MARK: Notifications
    
    func applicationWillTerminate(_ note: Notification) {
        
        window?.saveFrame(usingName: kWindowFrameKey)
    }

	func appNavigationKeyPressed(_ note: Notification) {

		guard let key = note.userInfo?[appNavigationKey] as? Int else {
			return
		}
		guard let contentView = window?.contentView, let view = note.object as? NSView, view.isDescendant(of: contentView) else {
			return
		}

		print(key)
	}

	func refreshProgressDidChange(_ note: Notification) {
		
		rs_performSelectorCoalesced(#selector(MainWindowController.coalescedMakeToolbarValidate(_:)), with: nil, afterDelay: 0.1)
	}
	
	// MARK: Toolbar
	
	func coalescedMakeToolbarValidate(_ sender: Any) {
		
		window?.toolbar?.validateVisibleItems()
	}
	
	// MARK: NSUserInterfaceValidations
	
	public func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
		
		if item.action == #selector(openArticleInBrowser(_:)) {
			return currentLink != nil
		}
        
        if item.action == #selector(showShareWindow(_:)) {
            if let link = currentLink {
                return URL(string: link) != nil
            } else {
                return false
            }
        }
		
		if item.action == #selector(nextUnread(_:)) {
			return canGoToNextUnread()
		}
		
		if item.action == #selector(markAllAsRead(_:)) {
			return canMarkAllAsRead()
		}
		
		return true
	}

	// MARK: Actions
	
	@IBAction func openArticleInBrowser(_ sender: AnyObject?) {
		
		if let link = currentLink {
			openInBrowser(link)
		}		
	}
    
    @IBAction func showShareWindow(_ sender: AnyObject) {
        if let link = currentLink, let url = URL(string: link) {
            let picker = NSSharingServicePicker(items: [url])
            picker.show(relativeTo: sender.bounds, of: sender as! NSView, preferredEdge: NSRectEdge.minY)
        }
    }
	
	@IBAction func nextUnread(_ sender: AnyObject?) {
		
		guard let timelineViewController = timelineViewController, let sidebarViewController = sidebarViewController else {
			return
		}
		
		func makeTimelineViewFirstResponder() {
			window!.makeFirstResponderUnlessDescendantIsFirstResponder(timelineViewController.tableView)
		}
		
		if timelineViewController.canGoToNextUnread() {
			timelineViewController.goToNextUnread()
			makeTimelineViewFirstResponder()
		}
		else if sidebarViewController.canGoToNextUnread() {
			sidebarViewController.goToNextUnread()
			makeTimelineViewFirstResponder()
		}
	}
	
	@IBAction func markAllAsRead(_ sender: AnyObject?) {
		
		timelineViewController?.markAllAsRead()
	}
	
	@IBAction func toggleSidebar(_ sender: AnyObject?) {
		
		splitViewController!.toggleSidebar(sender)
	}
}

private extension MainWindowController {
	
	var splitViewController: NSSplitViewController? {
		get {
			guard let viewController = contentViewController else {
				return nil
			}
			return viewController.childViewControllers.first as? NSSplitViewController
		}
	}

	var sidebarViewController: SidebarViewController? {
		get {
			return splitViewController?.splitViewItems[0].viewController as? SidebarViewController
		}
	}
	
	var timelineViewController: TimelineViewController? {
		get {
			return splitViewController?.splitViewItems[1].viewController as? TimelineViewController
		}
	}
	
	var detailSplitViewItem: NSSplitViewItem? {
		
		return splitViewController?.splitViewItems[2]
	}
	
	var detailViewController: DetailViewController? {

		get {
			return splitViewController?.splitViewItems[2].viewController as? DetailViewController
		}
	}

	var selectedArticles: [Article]? {
		get {
			return timelineViewController?.selectedArticles
		}
	}
	
	var oneSelectedArticle: Article? {
		get {
			if let articles = selectedArticles {
				return articles.count == 1 ? articles[0] : nil
			}
			return nil
		}
	}
	
	var currentLink: String? {
		get {
			if let article = oneSelectedArticle {
				return preferredLink(for: article)
			}
			return nil
		}
	}
	
	func canGoToNextUnread() -> Bool {
		
		guard let timelineViewController = timelineViewController, let sidebarViewController = sidebarViewController else {
			return false
		}

		return timelineViewController.canGoToNextUnread() || sidebarViewController.canGoToNextUnread()
	}
	
	func canMarkAllAsRead() -> Bool {
		
		return timelineViewController?.canMarkAllAsRead() ?? false
	}
}

