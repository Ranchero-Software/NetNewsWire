//
//  Authentication.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 05/12/2020.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

protocol AccountUpdater {
	var authenticationError: AccountUpdateErrors { get set }
}
