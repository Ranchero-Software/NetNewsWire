//
//  AddAccountPickerRow.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 13/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct AddAccountPickerRow: View {
	
	var accountType: AccountType
	
	var body: some View {
		HStack {
//			if let img = AppAssets.image(for: accountType) {
//				Image(rsImage: img)
//					.resizable()
//					.aspectRatio(contentMode: .fit)
//					.frame(width: 15, height: 15)
//			}
			
			switch accountType {
				case .onMyMac:
					Text(Account.defaultLocalAccountName)
				case .cloudKit:
					Text("iCloud")
				case .feedbin:
					Text("Feedbin")
				case .feedWrangler:
					Text("FeedWrangler")
				case .freshRSS:
					Text("FreshRSS")
				case .feedly:
					Text("Feedly")
				case .newsBlur:
					Text("NewsBlur")
			}
		}
	}
}

struct AddAccountPickerRow_Previews: PreviewProvider {
    static var previews: some View {
		AddAccountPickerRow(accountType: .onMyMac)
    }
}
