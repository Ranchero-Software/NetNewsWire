//
//  SelectURLBuilder.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/23/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit

protocol SelectURLBuilderDelegate: class {
	func selectURLBuilderDidBuildURL(_ url: URL)
}

protocol SelectURLBuilder {
	var delegate: SelectURLBuilderDelegate? { get set }
}
