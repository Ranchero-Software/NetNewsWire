//
//  OAuth1SwiftProvider.swift
//  Secrets
//
//  Created by Maurice Parker on 4/14/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import OAuthSwift

public protocol OAuth1SwiftProvider {
	
	static var oauth1Swift: OAuth1Swift { get }
	static var callbackURL: URL { get }
	
}
