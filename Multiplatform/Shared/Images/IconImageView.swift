//
//  IconImageView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/29/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct IconImageView: View {
	
	@Environment(\.colorScheme) var colorScheme
	var iconImage: IconImage
	
    var body: some View {
		GeometryReader { proxy in
			
			let newSize = newImageSize(viewSize: proxy.size)
			let tooShort = newSize.height < proxy.size.height
			let indistinguishable = colorScheme == .dark ? iconImage.isDark : iconImage.isBright
			let showBackground = (tooShort && !iconImage.isSymbol) || indistinguishable
			
			Group {
				Image(rsImage: iconImage.image)
					.resizable()
					.scaledToFit()
					.frame(width: newSize.width, height: newSize.height, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
			}
			.frame(width: proxy.size.width, height: proxy.size.height, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
			.background(showBackground ? AppAssets.iconBackgroundColor : nil)
			.cornerRadius(4)
			
		}
    }
	
	func newImageSize(viewSize: CGSize) -> CGSize {
		let imageSize = iconImage.image.size
		let newSize: CGSize
		
		if imageSize.height == imageSize.width {
			if imageSize.height >= viewSize.height {
				newSize = CGSize(width: viewSize.width, height: viewSize.height)
			} else {
				newSize = CGSize(width: imageSize.width, height: imageSize.height)
			}
		} else if imageSize.height > imageSize.width {
			let factor = viewSize.height / imageSize.height
			let width = imageSize.width * factor
			newSize = CGSize(width: width, height: viewSize.height)
		} else {
			let factor = viewSize.width / imageSize.width
			let height = imageSize.height * factor
			newSize = CGSize(width: viewSize.width, height: height)
		}
		
		return newSize
	}
	
}
