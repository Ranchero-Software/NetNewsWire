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
			.padding(.horizontal, 7)
			.background(SwiftUI.Color.gray.opacity(0.5))
			.cornerRadius(8)
    }
}

struct UnreadCountView_Previews: PreviewProvider {
    static var previews: some View {
		UnreadCountView(count: 123)
    }
}
