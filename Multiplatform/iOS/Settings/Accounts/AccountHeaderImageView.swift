//
//  AccountHeaderImageView.swift
//  Multiplatform iOS
//
//  Created by Rizwan on 08/07/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import RSCore

struct AccountHeaderImageView: View {
	var image: RSImage

	var body: some View {
		HStack(alignment: .center) {
			Spacer()
			Image(rsImage: image)
				.resizable()
				.scaledToFit()
				.frame(height: 48, alignment: .center)
				.foregroundColor(Color.primary)
			Spacer()
		}
		.padding(16)
	}
}

struct AccountHeaderImageView_Previews: PreviewProvider {
	static var previews: some View {
		Group {
			AccountHeaderImageView(image: AppAssets.image(for: .onMyMac)!)
			AccountHeaderImageView(image: AppAssets.image(for: .feedbin)!)
			AccountHeaderImageView(image: AppAssets.accountLocalPadImage)
		}
	}
}
