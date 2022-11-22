//
//  DerivedFeedTypes.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 14/11/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import Foundation
import SwiftUI
import RSCore

public enum DerivedFeed: CustomStringConvertible {
	
	case mastodon
	case substack
	
	public var description: String {
		switch self {
		case .mastodon:
			return NSLocalizedString("Add Mastodon User", comment: "Mastodon")
		case .substack:
			return NSLocalizedString("Add Substack Feed", comment: "Substack")
		}
	}
	
	var image: Image {
		switch self {
		case .mastodon:
			return Image("mastodon")
		case .substack:
			return Image("substack")
		}
	}
	
	var rsImageIcon: RSImage? {
		switch self {
		case .mastodon:
			return RSImage(named: "mastodon")
		case .substack:
			return RSImage(named: "substack")
		}
	}
	
	
}
