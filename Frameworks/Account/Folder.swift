//
//  Folder.swift
//  DataModel
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Data

public final class Folder: DisplayNameProvider, UnreadCountProvider {

	public let accountID: String
	var children = [Any]()
	var name: String?

	public var account: Account? {
		get {
			return accountWithID(accountID)
		}
	}
	
	// MARK: - DisplayNameProvider

	public var nameForDisplay: String {
		get {
			return name ?? NSLocalizedString("Untitled ƒ", comment: "Folder name")

		}
	}

	// MARK: - UnreadCountProvider

	public var unreadCount = 0 {
		didSet {
			if unreadCount != oldValue {
				postUnreadCountDidChangeNotification()
			}
		}
	}

	// MARK: - Init

	init(accountID: String, nameForDisplay: String) {
		
		self.accountID = accountID
		self.nameForDisplay = nameForDisplay
	}

	// MARK: - Disk Dictionary

	struct Key {
		static let name = "name"
		static let unreadCount = "unreadCount"
		static let childrenKey = "children"
	}

	convenience public init?(account: Account, dictionary: [String: Any]) {

		self.name = dictionary[Key.name]

		if let childrenArray = dictionary[Key.childrenKey] {
			self.childObjects = account.objects(with: childrenArray)
		}

		if let savedUnreadCount = dictionary[Key.unreadCount] as? Int {
			self.unreadCount = savedUnreadCount
		}
	}

	public var dictionary: [String: Any] {
		get {
			var d = [String: Any]()

			if let name = name {
				d[Key.name] = name
			}
			if unreadCount > 0 {
				d[Key.unreadCount] = unreadCount
			}

			// TODO: children as dictionaries - use method in Account


			let childObjects = children.flatMap { (child) -> [String: Any]? in

				if let feed = child as? Feed {

				}
			}

			return d
		}
	}

}

extension Folder: OPMLRepresentable {

	public func OPMLString(indentLevel: Int) -> String {

		let escapedTitle = nameForDisplay.rs_stringByEscapingSpecialXMLCharacters()
		var s = "<outline text=\"\(escapedTitle)\" title=\"\(escapedTitle)\">\n"
		s = s.rs_string(byPrependingNumberOfTabs: indentLevel)

		var hasAtLeastOneChild = false

		let _ = visitChildren { (oneChild) -> Bool in

			if let oneOPMLObject = oneChild as? OPMLRepresentable {
				s += oneOPMLObject.OPMLString(indentLevel: indentLevel + 1)
				hasAtLeastOneChild = true
			}
			return false
		}

		if !hasAtLeastOneChild {
			s = "<outline text=\"\(escapedTitle)\" title=\"\(escapedTitle)\"/>\n"
			s = s.rs_string(byPrependingNumberOfTabs: indentLevel)
			return s
		}

		s = s + NSString.rs_string(withNumberOfTabs: indentLevel) + "</outline>\n"

		return s
	}
}

