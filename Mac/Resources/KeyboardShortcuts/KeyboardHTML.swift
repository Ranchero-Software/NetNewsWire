//
//  KeyboardHTML.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 05/06/2023.
//  Copyright © 2023 Ranchero Software. All rights reserved.
//

import Html
import AppKit
import RSCore

protocol LocalizedKeyboardShortcut {
	var localizedDescription: String { get }
	var localizedShortcut: String { get }
}

enum KeyboardShortcuts {
	
	enum Everywhere: CaseIterable, LocalizedKeyboardShortcut {
		
		case scrollOrGoToNextUnread // space
		case goToNextUnread // n or +
		case toggleReadStatus // r or u
		case markAllAsRead // k
		case markOlderArticlesAsRead // o
		case markAllAsReadGoToNextUnread // l
		case markAsUnreadGoToNextUnread // m
		case toggleStarredStatus // s
		case openInBrowser // b or &#9166; or Enter
		case previousSubscription // a
		case nextSubscription // z
		
		var localizedDescription: String {
			switch self {
			case .scrollOrGoToNextUnread:
				return NSLocalizedString("keyboard.text.scroll-or-go-to-next-unread", comment: "Scroll or go to next unread")
			case .goToNextUnread:
				return NSLocalizedString("keyboard.text.go-to-next-unread", comment: "Go to next unread")
			case .toggleReadStatus:
				return NSLocalizedString("keyboard.text.toggle-read-status", comment: "Toggle read status")
			case .markAllAsRead:
				return NSLocalizedString("keyboard.text.mark-all-as-read", comment: "Mark all as read")
			case .markOlderArticlesAsRead:
				return NSLocalizedString("keyboard.text.mark-older-articles-as-read", comment: "Mark older articles as read")
			case .markAllAsReadGoToNextUnread:
				return NSLocalizedString("keyboard.text.mark-all-as-read-go-to-next-unread", comment: "Mark all as read, go to next unread")
			case .markAsUnreadGoToNextUnread:
				return NSLocalizedString("keyboard.text.mark-as-unread-go-to-next-unread", comment: "Mark as unread, go to next unread")
			case .toggleStarredStatus:
				return NSLocalizedString("keyboard.text.toggle-starred-status", comment: "Toggle starred status")
			case .openInBrowser:
				return NSLocalizedString("keyboard.text.open-in-browser", comment: "Open in browser")
			case .previousSubscription:
				return NSLocalizedString("keyboard.text.previous-subscription", comment: "Previous subscription")
			case .nextSubscription:
				return NSLocalizedString("keyboard.text.next-subscription", comment: "Next subscription")
			}
		}
		
		var localizedShortcut: String {
			switch self {
			case .scrollOrGoToNextUnread:
				return NSLocalizedString("keyboard.shortcut.scroll-or-go-to-next-unread", comment: "Space bar")
			case .goToNextUnread:
				return NSLocalizedString("keyboard.shortcut.go-to-next-unread", comment: "n or +")
			case .toggleReadStatus:
				return NSLocalizedString("keyboard.shortcut.toggle-read-status", comment: "r or u")
			case .markAllAsRead:
				return NSLocalizedString("keyboard.shortcut.mark-all-as-read", comment: "k")
			case .markOlderArticlesAsRead:
				return NSLocalizedString("keyboard.shortcut.mark-older-articles-as-read", comment: "o")
			case .markAllAsReadGoToNextUnread:
				return NSLocalizedString("keyboard.shortcut.mark-all-as-read-go-to-next-unread", comment: "l")
			case .markAsUnreadGoToNextUnread:
				return NSLocalizedString("keyboard.shortcut.mark-as-unread-go-to-next-unread", comment: "m")
			case .toggleStarredStatus:
				return NSLocalizedString("keyboard.shortcut.toggle-starred-status", comment: "s")
			case .openInBrowser:
				return NSLocalizedString("keyboard.shortcut.open-in-browser", comment: "b or ⏎ or Enter")
			case .previousSubscription:
				return NSLocalizedString("keyboard.shortcut.previous-subscription", comment: "a")
			case .nextSubscription:
				return NSLocalizedString("keyboard.shortcut.next-subscription", comment: "z")
			}
			
		}
		
	}
	
	enum LeftSidebar: CaseIterable, LocalizedKeyboardShortcut {
		
		case collapse
		case expand
		case collapseAllExcludingGrouped
		case expandAll
		case moveFocusToHeadlines
		
		var localizedDescription: String {
			switch self {
				
			case .collapse:
				return NSLocalizedString("keyboard.text.collapse", comment: "Collapse")
			case .expand:
				return NSLocalizedString("keyboard.text.expand", comment: "Expand")
			case .collapseAllExcludingGrouped:
				return NSLocalizedString("keyboard.text.collapse-all-excluding-grouped", comment: "Collapse All (except for group items)")
			case .expandAll:
				return NSLocalizedString("keyboard.text.expand-all", comment: "Expand All")
			case .moveFocusToHeadlines:
				return NSLocalizedString("keyboard.text.move-focus-headline", comment: "Move focus to headlines")
			}
		}
		
		var localizedShortcut: String {
			switch self {
			case .collapse:
				return NSLocalizedString("keyboard.shortcut.collapse", comment: "Keyboard shortcut: , or ⌥+←")
			case .expand:
				return NSLocalizedString("keyboard.shortcut.expand", comment: "Keyboard shortcut: . or ⌥+→")
			case .collapseAllExcludingGrouped:
				return NSLocalizedString("keyboard.shortcut.collapse-all-excluding-grouped", comment: "Keyboard shortcut: ; or ⌥+⌘+←")
			case .expandAll:
				return NSLocalizedString("keyboard.shortcut.expand-all", comment: "Keyboard shortcut: ' or ⌥+⌘+→")
			case .moveFocusToHeadlines:
				return NSLocalizedString("keyboard.shortcut.move-focus-headline", comment: "Keyboard shortcut: →")
			}
		}
		
		
	}
	
	enum Timeline: CaseIterable, LocalizedKeyboardShortcut {
		
		case moveFocusToSubscriptions
		case moveFocusToDetail
		
		var localizedDescription: String {
			switch self {
			case .moveFocusToSubscriptions:
				return NSLocalizedString("keyboard.text.move-focus-to-subscriptions", comment: "Move focus to subscriptions")
			case .moveFocusToDetail:
				return NSLocalizedString("keyboard.text.move-focus-to-detail", comment: "Move focus to detail")
			}
		}
		
		var localizedShortcut: String {
			switch self {
			case .moveFocusToSubscriptions:
				return NSLocalizedString("keyboard.shortcut.move-focus-to-subscriptions", comment: "Keyboard shortcut: ←")
			case .moveFocusToDetail:
				return NSLocalizedString("keyboard.shortcut.move-focus-to-detail", comment: "Keyboard shortcut: →")
			}
		}
	}
	
	enum Detail: CaseIterable, LocalizedKeyboardShortcut {
		
		case moveFocusToHeadlines
		
		var localizedDescription: String {
			switch self {
			case .moveFocusToHeadlines:
				return NSLocalizedString("keyboard.text.move-focus-to-headlines", comment: "Move focus to headlines")
			}
		}
		
		var localizedShortcut: String {
			switch self {
			case .moveFocusToHeadlines:
				return NSLocalizedString("keyboard.shortcut.move-focus-to-headlines", comment: "Keyboard shortcut: ←")
			}
		}
		
		
	}
	
}


struct KeyboardHTML: Logging {

	private func stylesheet() -> StaticString {
	"""
		body {
			margin: 2em;
			color: #333333;
			background-color: white;
			line-height: 1.4em;
			font-family: -apple-system;
		}
		@media (prefers-color-scheme: dark) {
			body {
				color: white;
				background-color: #333333;
			}
			
			table tr:nth-child(odd) {
				background-color: #1E1E1E !important;
			}
		}
		table {
			width: 100%;
			line-height: 2.0em;
			border-collapse: collapse;
			margin-top: 1.0em;
			margin-bottom: 1.0em;
		}
		table tr:nth-child(odd) {
			background-color: #F0F0F0;
		}
		table tr td:first-child {
			width: 60%;
		}
		table td {
			padding: 0;
		}
		table caption {
			text-align: left;
			font-weight: bold;
			font-style: italic;
		}
		kbd {
			font-family: -apple-system;
		}
		em {
			font-weight: bold;
		}
	"""
	}
	
	private func document() -> Node {
		return Node.document(
			.html(
				.head(
					  .style(safe: stylesheet()),
					  .meta(contentType: .text(.html, charset: .utf8))
				),
				.body(
					// Heading & Description
					Node.h1(.text(NSLocalizedString("label.text.keyboard-shortcuts", comment: "Keyboard Shortcuts"))),
					Node.p(.raw(NSLocalizedString("label.text.keyboard-shortcuts-description", comment: "Keyboard Shortcuts Description"))),
					
					// Shortcuts Available Everywhere
					Node.em(.text(NSLocalizedString("label.text.keyboard-shortcuts-everywhere", comment: "Everywhere..."))),
					Node.table(
						.tbody(
							.fragment(
								KeyboardShortcuts.Everywhere.allCases.map { shortcut in
									.tr(
										.td(.text(shortcut.localizedDescription)),
										.td(.kbd(.text(shortcut.localizedShortcut)))
									)
								}
							)
						)
					),
					
					// Shortcuts Available in Left Sidebar
					Node.em(.text(NSLocalizedString("label.text.keyboard-shortcuts-left-sidebar", comment: "Left Sidebar..."))),
					Node.table(
						.tbody(
							.fragment(
								KeyboardShortcuts.LeftSidebar.allCases.map { shortcut in
									.tr(
										.td(.text(shortcut.localizedDescription)),
										.td(.kbd(.text(shortcut.localizedShortcut)))
									)
								}
							)
						)
					),
					
					// Timeline
					Node.em(.text(NSLocalizedString("label.text.keyboard-shortcuts-timeline", comment: "Timeline only..."))),
					Node.table(
						.tbody(
							.fragment(
								KeyboardShortcuts.Timeline.allCases.map { shortcut in
									.tr(
										.td(.text(shortcut.localizedDescription)),
										.td(.kbd(.text(shortcut.localizedShortcut)))
									)
								}
							)
						)
					),
					
					// Detail
					Node.em(.text(NSLocalizedString("label.text.keyboard-shortcuts-detail", comment: "Detail only..."))),
					Node.table(
						.tbody(
							.fragment(
								KeyboardShortcuts.Detail.allCases.map { shortcut in
									.tr(
										.td(.text(shortcut.localizedDescription)),
										.td(.kbd(.text(shortcut.localizedShortcut)))
									)
								}
							)
						)
					)
					
				)
			)
		)
	}
	
	func renderedDocument() -> String {
		return render(document())
	}
	
	func htmlFile() -> String {
		let appSupport = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
		let file = appSupport.appendingPathComponent("keyboardshortcuts", conformingTo: .html)
		if FileManager.default.createFile(atPath: file.path(), contents: renderedDocument().data(using: .utf8)) {
			return file.path()
		} else {
			KeyboardHTML.logger.error("Unable to create keyboard shortcuts HTML.")
			return file.path()
		}
	}
	
}





