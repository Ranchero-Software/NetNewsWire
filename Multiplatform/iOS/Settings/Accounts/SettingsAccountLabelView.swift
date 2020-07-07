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
				.aspectRatio(1, contentMode: .fit)
				.frame(height: 32)
			Text(verbatim: accountLabel).font(.title)
		}
		.foregroundColor(.primary).padding(4.0)
	}
}

struct SettingsAccountLabelView_Previews: PreviewProvider {
    static var previews: some View {
		SettingsAccountLabelView(
			accountImage: AppAssets.image(for: .onMyMac),
			accountLabel: "On My Device"
		)
		.previewLayout(.fixed(width: 300, height: 44))
    }
}
