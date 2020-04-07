//
//  ExtensionPoint.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore

protocol ExtensionPoint {

	/// The title of the command.
	var title: String { get }

	/// The template image for the command.
	var templateImage: RSImage { get }

}
