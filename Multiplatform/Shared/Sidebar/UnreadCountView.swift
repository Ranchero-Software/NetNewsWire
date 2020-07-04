//
//  UnreadCountView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/29/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct UnreadCountView: View {
	
	var count: Int
	
    var body: some View {
		Text(verbatim: String(count))
			.font(.caption)
			.fontWeight(.bold)
			.padding(.horizontal, 7)
			.padding(.vertical, 1)
			.background(AppAssets.sidebarUnreadCountBackground)
			.foregroundColor(AppAssets.sidebarUnreadCountForeground)
			.cornerRadius(8)
    }
}

struct UnreadCountView_Previews: PreviewProvider {
    static var previews: some View {
		UnreadCountView(count: 123)
    }
}
