//
//  DetailWindowState.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 12/16/23.
//  Copyright © 2023 Ranchero Software. All rights reserved.
//

import Foundation

class DetailWindowState: NSObject, NSSecureCoding {
	
	static var supportsSecureCoding = true
	
	let isShowingExtractedArticle: Bool
	let windowScrollY: CGFloat
	
	internal init(isShowingExtractedArticle: Bool, windowScrollY: CGFloat) {
		self.isShowingExtractedArticle = isShowingExtractedArticle
		self.windowScrollY = windowScrollY
	}
	
	required init?(coder: NSCoder) {
		isShowingExtractedArticle = coder.decodeBool(forKey: "isShowingExtractedArticle")
		windowScrollY = coder.decodeObject(of: NSNumber.self, forKey: "windowScrollY") as? CGFloat ?? 0
	}
	
	func encode(with coder: NSCoder) {
		coder.encode(isShowingExtractedArticle, forKey: "isShowingExtractedArticle")
		coder.encode(windowScrollY, forKey: "windowScrollY")
	}
	
}
