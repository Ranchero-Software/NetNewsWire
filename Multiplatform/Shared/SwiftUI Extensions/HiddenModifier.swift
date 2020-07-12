//
//  HiddenModifier.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 7/12/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

extension View {
	func hidden(_ hide: Bool) -> some View {
		Group {
			if hide {
				self.hidden()
			} else {
				self
			}
		}
	}
}
