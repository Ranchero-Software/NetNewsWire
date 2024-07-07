//
//  SecretsProvider.swift
//  
//
//  Created by Maurice Parker on 7/30/20.
//

import Foundation

public protocol SecretsProvider {
	var mercuryClientId: String { get }
	var mercuryClientSecret: String { get }
	var feedlyClientId: String { get }
	var feedlyClientSecret: String { get }
	var inoreaderAppId: String { get }
	var inoreaderAppKey: String { get }
}
