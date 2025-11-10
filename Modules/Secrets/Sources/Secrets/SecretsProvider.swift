//
//  SecretsProvider.swift
//  
//
//  Created by Maurice Parker on 7/30/20.
//

import Foundation

public protocol SecretsProvider {
	var mercuryClientID: String { get }
	var mercuryClientSecret: String { get }
	var feedlyClientID: String { get }
	var feedlyClientSecret: String { get }
	var inoreaderAppID: String { get }
	var inoreaderAppKey: String { get }
}
