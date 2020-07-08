//
//  SettingsAccountLabelView.swift
//  Multiplatform iOS
//
//  Created by Rizwan on 07/07/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import RSCore

struct SettingsAccountLabelView: View {
	let accountImage: RSImage?
	let accountLabel: String

	var body: some View {
		HStack {
			Image(rsImage: accountImage!)
				.resizable()
				.scaledToFit()
				.frame(width: 32, height: 32)
			Text(verbatim: accountLabel).font(.title)
		}
		.foregroundColor(.primary).padding(4.0)
	}
}

struct SettingsAccountLabelView_Previews: PreviewProvider {
    static var previews: some View {
		List {
			SettingsAccountLabelView(
				accountImage: AppAssets.image(for: .onMyMac),
				accountLabel: "On My Device"
			)
			SettingsAccountLabelView(
				accountImage: AppAssets.image(for: .feedbin),
				accountLabel: "Feedbin"
			)
			SettingsAccountLabelView(
				accountImage: AppAssets.accountLocalPadImage,
				accountLabel: "On My iPad"
			)
			SettingsAccountLabelView(
				accountImage: AppAssets.accountLocalPhoneImage,
				accountLabel: "On My iPhone"
			)
		}
    }
}
