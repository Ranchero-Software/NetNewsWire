//
//  TimelineItemView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 7/1/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct TimelineItemView: View {
	
	var timelineItem: TimelineItem
	
    var body: some View {
		VStack {
			Text(verbatim: timelineItem.article.title ?? "N/A")
				.frame(maxWidth: .infinity, alignment: .leading)
			Divider()
		}
    }
}

//struct TimelineItemView_Previews: PreviewProvider {
//    static var previews: some View {
//        TimelineItemView()
//    }
//}
