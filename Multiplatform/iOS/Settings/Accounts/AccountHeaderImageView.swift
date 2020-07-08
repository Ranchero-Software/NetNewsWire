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
		Image(rsImage: image)
			.resizable()
			.aspectRatio(1, contentMode: .fit)
			.frame(height: 48, alignment: .center)
			.padding()
		
	}
}

struct AccountHeaderImageView_Previews: PreviewProvider {
	static var previews: some View {
		AccountHeaderImageView(image: AppAssets.image(for: .onMyMac)!)
	}
}
