//
//  ConfiguredAccountRow.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 13/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct ConfiguredAccountRow: View {
	
	var account: Account
	
	var body: some View {
		HStack(alignment: .center) {
			if let img = account.smallIcon?.image {
				Image(rsImage: img)
					.resizable()
					.frame(width: 20, height: 20)
					.aspectRatio(contentMode: .fit)
			}
			Text(account.nameForDisplay)
		}.padding(.vertical, 4)
	}
	
}

