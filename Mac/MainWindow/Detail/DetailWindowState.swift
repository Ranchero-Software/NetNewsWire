//
//  DetailWindowState.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 12/16/23.
//  Copyright © 2023 Ranchero Software. All rights reserved.
//

import Foundation

final class DetailWindowState: NSObject, NSSecureCoding {

	static let supportsSecureCoding = true

	let isShowingExtractedArticle: Bool
	let windowScrollY: CGFloat

	init(isShowingExtractedArticle: Bool, windowScrollY: CGFloat) {
		self.isShowingExtractedArticle = isShowingExtractedArticle
		self.windowScrollY = windowScrollY
	}

	private struct Key {
		static let isShowingExtractedArticle = "isShowingExtractedArticle"
		static let windowScrollY = "windowScrollY"
	}

	required init?(coder: NSCoder) {
		isShowingExtractedArticle = coder.decodeBool(forKey: Key.isShowingExtractedArticle)
		windowScrollY = CGFloat(coder.decodeDouble(forKey: Key.windowScrollY))
	}

	func encode(with coder: NSCoder) {
		coder.encode(isShowingExtractedArticle, forKey: Key.isShowingExtractedArticle)
		coder.encode(Double(windowScrollY), forKey: Key.windowScrollY)
	}
}
