//
//  RootSplitViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/4/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import Account
import Articles

final class RootSplitViewController: UISplitViewController {

	var coordinator: SceneCoordinator!

	override var keyCommands: [UIKeyCommand]? {
		AppCommands.keyCommands(for: .global)
	}

	override var prefersStatusBarHidden: Bool {
		return coordinator.prefersStatusBarHidden
	}

	override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
		return .slide
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		coordinator.resetFocus()
	}

	/// Show a column for programmatic navigation.
	/// Pass `bypassDisplayModeRestriction: true` for user-initiated navigation, so it can
	/// reveal a column the display-mode suppression below would otherwise keep hidden.
	/// <https://github.com/Ranchero-Software/NetNewsWire/issues/3138>
	func showColumn(_ column: UISplitViewController.Column, bypassDisplayModeRestriction: Bool = false) {
		guard !coordinator.isNavigationDisabled else { return }

		/// Always show the column on iPhone
		if UIDevice.current.userInterfaceIdiom == .phone {
			show(column)
			return
		}

		/// In certain scenarios, we don't want to select a feed or article
		/// and have the display mode change as this interferes with state
		/// restoration of the feeds and timeline display modes.
		if !bypassDisplayModeRestriction {

			/// Don't show primary when the display mode is timeline + article or article only.
			if column == .primary && (displayMode == .oneBesideSecondary || displayMode == .secondaryOnly) {
				return
			}

			/// Don't show the timeline when the display mode is article only.
			if column == .supplementary && displayMode == .secondaryOnly {
				return
			}
		}

		show(column)
	}

	// MARK: Keyboard Shortcuts

	@objc func scrollOrGoToNextUnread(_ sender: Any?) {
		coordinator.scrollOrGoToNextUnread()
	}

	@objc func scrollUp(_ sender: Any?) {
		coordinator.scrollUp()
	}

	@objc func goToPreviousUnread(_ sender: Any?) {
		coordinator.selectPrevUnread()
	}

	@objc func nextUnread(_ sender: Any?) {
		coordinator.selectNextUnread()
	}

	@objc func markUnreadAndGoToNextUnread(_ sender: Any?) {
		coordinator.markAsUnreadForCurrentArticle()
		coordinator.selectNextUnread()
	}

	@objc func markAllAsReadAndGoToNextUnread(_ sender: Any?) {
		if !coordinator.isTimelineUnreadAvailable {
			coordinator.selectNextUnread()
			return
		}
		let articlesToMark = coordinator.articles
		let title = NSLocalizedString("Mark All as Read", comment: "Command")

		let completion: () -> Void = { [weak self] in
			guard let self else {
				return
			}
			self.coordinator.markAsReadAndShowSidebar(articlesToMark) {
				self.coordinator.selectNextUnread()
			}
		}

		confirmMarkAllAsRead(title: title, completion: completion)
	}

	@objc func markAboveAsRead(_ sender: Any?) {
		coordinator.markAboveAsRead()
	}

	@objc func markBelowAsRead(_ sender: Any?) {
		coordinator.markBelowAsRead()
	}

	@objc func goToPreviousSubscription(_ sender: Any?) {
		coordinator.selectPrevFeed()
	}

	@objc func goToNextSubscription(_ sender: Any?) {
		coordinator.selectNextFeed()
	}

	@objc func openInBrowser(_ sender: Any?) {
		coordinator.showBrowserForCurrentArticleOrFeed()
	}

	/// The Article menu's Open in Browser is about the article, so it has its own action
	/// and stays disabled with nothing selected. The B shortcut above is the one that
	/// falls back to the feed.
	@objc func openArticleInBrowser(_ sender: Any?) {
		coordinator.showBrowserForCurrentArticle()
	}

	@objc func openInAppBrowser(_ sender: Any?) {
		coordinator.showInAppBrowser()
	}

	@objc func articleSearch(_ sender: Any?) {
		coordinator.showSearch()
	}

	@objc func addNewFeed(_ sender: Any?) {
		coordinator.showAddFeed()
	}

	@objc func addNewFolder(_ sender: Any?) {
		coordinator.showAddFolder()
	}

	@objc func cleanUp(_ sender: Any?) {
		coordinator.cleanUp(conditional: false)
	}

	@objc func toggleReadFeedsFilter(_ sender: Any?) {
		coordinator.toggleReadFeedsFilter()
		UIMenuSystem.main.setNeedsRebuild()
	}

	@objc func toggleReadArticlesFilter(_ sender: Any?) {
		coordinator.toggleReadArticlesFilter()
		UIMenuSystem.main.setNeedsRebuild()
	}

	@objc func refresh(_ sender: Any?) {
		appDelegate.manualRefresh(errorHandler: ErrorHandler.present(self))
	}

	@objc func goToToday(_ sender: Any?) {
		coordinator.selectTodayFeed()
	}

	@objc func goToAllUnread(_ sender: Any?) {
		coordinator.selectAllUnreadFeed()
	}

	@objc func goToStarred(_ sender: Any?) {
		coordinator.selectStarredFeed()
	}

	@objc func goToSettings(_ sender: Any?) {
		coordinator.showSettings()
	}

	@objc func toggleRead(_ sender: Any?) {
		coordinator.toggleReadForCurrentArticle()
	}

	@objc func toggleReaderView(_ sender: Any?) {
		coordinator.toggleReaderViewForCurrentArticle()
	}

	@objc func toggleStarred(_ sender: Any?) {
		coordinator.toggleStarredForCurrentArticle()
	}

	@objc func markAllAsRead(_ sender: Any?) {
		let title = NSLocalizedString("Mark All as Read", comment: "Command")

		// Capture the articles before the confirmation alert, so switching folders
		// while it's up can't mark the wrong folder.
		// <https://github.com/Ranchero-Software/NetNewsWire/issues/5359>
		let articlesToMark = coordinator.articles

		confirmMarkAllAsRead(title: title) { [weak self] in
			self?.coordinator.markAsReadAndShowSidebar(articlesToMark)
		}
	}

	@objc func markOlderArticlesAsRead(_ sender: Any?) {
		if coordinator.sortDirection == .orderedDescending {
			coordinator.markBelowAsRead()
		} else {
			coordinator.markAboveAsRead()
		}
	}

	@objc func openInBrowserUsingOppositeOfSettings(_ sender: Any?) {
		coordinator.openInBrowserUsingOppositeOfSettings()
	}

	@objc func sortByNewestArticleOnTop(_ sender: Any?) {
		AppDefaults.shared.timelineSortDirection = .orderedDescending
		UIMenuSystem.main.setNeedsRebuild()
	}

	@objc func sortByOldestArticleOnTop(_ sender: Any?) {
		AppDefaults.shared.timelineSortDirection = .orderedAscending
		UIMenuSystem.main.setNeedsRebuild()
	}

	@objc func groupByFeedToggled(_ sender: Any?) {
		AppDefaults.shared.timelineGroupByFeed.toggle()
		UIMenuSystem.main.setNeedsRebuild()
	}

	@objc func showFeedInspector(_ sender: Any?) {
		coordinator.showFeedInspector()
	}

	@objc func showCurrentActivity(_ sender: Any?) {
		coordinator.showCurrentActivity()
	}

	@objc func beginFind(_ sender: Any?) {
		coordinator.beginFindInArticle()
	}

	@objc func importOPML(_ sender: Any?) {
		coordinator.importOPML()
	}

	@objc func exportOPML(_ sender: Any?) {
		coordinator.exportOPML()
	}

	// MARK: - Mark All as Read Confirmation

	/// Anchors the confirmation to the Mark All as Read button when the timeline is
	/// showing one. Menu items and keyboard shortcuts have no source view, so they
	/// fall back to the split view.
	/// <https://github.com/Ranchero-Software/NetNewsWire/issues/5370>
	private func confirmMarkAllAsRead(title: String, completion: @escaping () -> Void) {
		if let markAllAsReadButton = (viewController(for: .supplementary) as? MainTimelineModernViewController)?.markAllAsReadButton {
			MarkAsReadAlertController.confirm(self, coordinator: coordinator, confirmTitle: title, sourceType: markAllAsReadButton, completion: completion)
		} else {
			MarkAsReadAlertController.confirm(self, coordinator: coordinator, confirmTitle: title, sourceType: view as UIView, completion: completion)
		}
	}

	// MARK: - Menu Validation

	/// The open-in-browser commands work on the current article, or, with none selected,
	/// on the selected feed's home page.
	private var hasSomethingToOpen: Bool {
		coordinator.currentArticle != nil || coordinator.currentFeedHomePageURL != nil
	}

	override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
		switch action {
		case #selector(toggleRead(_:)), #selector(toggleStarred(_:)),
			 #selector(markUnreadAndGoToNextUnread(_:)), #selector(toggleReaderView(_:)), #selector(beginFind(_:)):
			return coordinator.currentArticle != nil
		case #selector(openArticleInBrowser(_:)):
			return coordinator.currentArticle != nil && coordinator.canOpenBrowser()
		case #selector(openInBrowserUsingOppositeOfSettings(_:)):
			return coordinator.currentArticle != nil && coordinator.canOpenBrowser(invertBrowserPreference: true)
		case #selector(openInBrowser(_:)):
			return hasSomethingToOpen && coordinator.canOpenBrowser()
		case #selector(openInAppBrowser(_:)):
			return hasSomethingToOpen && !coordinator.isShowingInAppBrowser
		case #selector(markAboveAsRead(_:)):
			guard let currentArticle = coordinator.currentArticle else {
				return false
			}
			return coordinator.canMarkAboveAsRead(for: currentArticle)
		case #selector(markBelowAsRead(_:)):
			guard let currentArticle = coordinator.currentArticle else {
				return false
			}
			return coordinator.canMarkBelowAsRead(for: currentArticle)
		case #selector(markOlderArticlesAsRead(_:)):
			guard let currentArticle = coordinator.currentArticle else {
				return false
			}
			if coordinator.sortDirection == .orderedDescending {
				return coordinator.canMarkBelowAsRead(for: currentArticle)
			} else {
				return coordinator.canMarkAboveAsRead(for: currentArticle)
			}
		case #selector(nextUnread(_:)):
			return coordinator.isNextUnreadAvailable
		case #selector(scrollOrGoToNextUnread(_:)):
			return coordinator.currentArticle != nil || coordinator.isNextUnreadAvailable
		case #selector(markAllAsRead(_:)):
			return coordinator.isTimelineUnreadAvailable
		case #selector(markAllAsReadAndGoToNextUnread(_:)):
			// Stays enabled with a fully-read timeline: the action falls back to
			// going to the next unread article elsewhere.
			return coordinator.isTimelineUnreadAvailable || coordinator.isNextUnreadAvailable
		case #selector(showFeedInspector(_:)):
			return coordinator.timelineFeed is Feed || coordinator.currentArticle?.feed != nil
		default:
			return super.canPerformAction(action, withSender: sender)
		}
	}

	override func validate(_ command: UICommand) {
		super.validate(command)

		switch command.action {
		case #selector(toggleRead(_:)):
			command.title = coordinator.currentArticle?.status.read ?? false ?
				NSLocalizedString("Mark as Unread", comment: "Command") :
				NSLocalizedString("Mark as Read", comment: "Command")
		case #selector(toggleStarred(_:)):
			command.title = coordinator.currentArticle?.status.starred ?? false ?
				NSLocalizedString("Mark as Unstarred", comment: "Command") :
				NSLocalizedString("Mark as Starred", comment: "Command")
		case #selector(groupByFeedToggled(_:)):
			command.state = AppDefaults.shared.timelineGroupByFeed ? .on : .off
		case #selector(sortByNewestArticleOnTop(_:)):
			command.state = AppDefaults.shared.timelineSortDirection == .orderedDescending ? .on : .off
		case #selector(sortByOldestArticleOnTop(_:)):
			command.state = AppDefaults.shared.timelineSortDirection == .orderedAscending ? .on : .off
		case #selector(toggleReadArticlesFilter(_:)):
			command.state = coordinator.isReadArticlesFiltered ? .on : .off
		case #selector(toggleReadFeedsFilter(_:)):
			command.state = coordinator.isReadFeedsFiltered ? .on : .off
		default:
			break
		}
	}
}
