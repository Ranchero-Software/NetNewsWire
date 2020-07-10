//
//  ArticleManager.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 7/9/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Articles

protocol ArticleManager: class {
	var currentArticle: Article? { get }
}
