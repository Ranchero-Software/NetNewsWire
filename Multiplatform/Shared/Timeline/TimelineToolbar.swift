//
//  TimelineToolbar.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 7/3/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct TimelineToolbar: View {
	
	var body: some View {
		VStack {
			Divider()
			HStack(alignment: .center) {
				Button(action: {
				}, label: {
					AppAssets.markAllAsReadImage
						.resizable()
						.scaledToFit()
						.frame(width: 24, height: 24, alignment: .center)
						.foregroundColor(.accentColor)
				}).help("Mark All As Read")
				
				Spacer()
				
				Text("Last updated")
					.font(.caption)
					.foregroundColor(.secondary)
				
				Spacer()
				
				Button(action: {
				}, label: {
					AppAssets.nextUnreadArticleImage
						.font(.title3)
						.foregroundColor(.accentColor)
				})
				.help("Next Unread")
			}
			.padding(.horizontal, 16)
			.padding(.bottom, 12)
			.padding(.top, 4)
		}
		.background(VisualEffectBlur(blurStyle: .systemChromeMaterial).edgesIgnoringSafeArea(.bottom))
	
	}
}


struct TimelineToolbar_Previews: PreviewProvider {
    static var previews: some View {
        TimelineToolbar()
    }
}
