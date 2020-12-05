//
//  AddNewsBlurViewModel.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 05/12/2020.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import RSCore
import RSWeb
import Secrets

class AddNewsBlurViewModel: ObservableObject {
	@Published var isAuthenticating: Bool = false
	@Published var accountUpdateError: AccountUpdateErrors = .none
	@Published var showError: Bool = false
	@Published var username: String = ""
	@Published var password: String = ""
}
