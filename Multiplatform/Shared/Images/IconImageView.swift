//
//  IconImageView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/29/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct IconImageView: View {
	
	var iconImage: IconImage
	
    var body: some View {
		return Image(rsImage: iconImage.image)
			.resizable()
			.scaledToFit()
			.cornerRadius(4)
    }
}

struct IconImageView_Previews: PreviewProvider {
    static var previews: some View {
		IconImageView(iconImage: IconImage(AppAssets.faviconTemplateImage))
    }
}
