//
//  OAuth2SwiftProvider.swift
//  Secrets
//
//  Created by Maurice Parker on 5/2/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

import OAuthSwift

public protocol OAuth2SwiftProvider {
	
	static var oauth2Swift: OAuth2Swift { get }
	static var callbackURL: URL { get }
	static var oauth2Vars: (state: String, scope: String, params: [String: String]) { get }
	
}
