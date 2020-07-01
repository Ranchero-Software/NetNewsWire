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
		Text(verbatim: timelineItem.article.title ?? "N/A")
    }
}

//struct TimelineItemView_Previews: PreviewProvider {
//    static var previews: some View {
//        TimelineItemView()
//    }
//}
