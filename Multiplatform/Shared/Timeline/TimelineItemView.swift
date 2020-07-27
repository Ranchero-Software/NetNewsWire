//
//  TimelineItemView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 7/1/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct TimelineItemView: View {
	
	@EnvironmentObject var defaults: AppDefaults
	@StateObject var articleIconImageLoader = ArticleIconImageLoader()
	
	var selected: Bool
	var width: CGFloat
	var timelineItem: TimelineItem

	#if os(macOS)
	var verticalPadding: CGFloat = 10
	#endif
	#if os(iOS)
	var verticalPadding: CGFloat = 0
	#endif

    var body: some View {
		HStack(alignment: .top) {
			TimelineItemStatusView(selected: selected, status: timelineItem.status)
			if let image = articleIconImageLoader.image {
				IconImageView(iconImage: image)
					.frame(width: CGFloat(defaults.timelineIconDimensions), height: CGFloat(defaults.timelineIconDimensions), alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
			}
			VStack {
				let titleLines = timelineItem.numberOfTitleLines(width: width)
				if titleLines > 0 {
					Text(verbatim: timelineItem.truncatedTitle)
						.fontWeight(.semibold)
						.lineLimit(titleLines)
						.frame(maxWidth: .infinity, alignment: .leading)
						.padding(.trailing, 4)
						.fixedSize(horizontal: false, vertical: true)
				}
				let summaryLines = timelineItem.numberOfSummaryLines(width: width, titleLines: titleLines)
				if summaryLines > 0 {
					Text(verbatim: timelineItem.truncatedSummary)
						.lineLimit(summaryLines)
						.frame(maxWidth: .infinity, alignment: .leading)
						.padding(.trailing, 4)
						.fixedSize(horizontal: false, vertical: true)
				}
				Spacer(minLength: 0)
				HStack {
					Text(verbatim: timelineItem.byline)
						.lineLimit(1)
						.truncationMode(.tail)
						.font(.footnote)
						.foregroundColor(.secondary)
					Spacer()
					Text(verbatim: timelineItem.dateTimeString)
						.lineLimit(1)
						.font(.footnote)
						.foregroundColor(.secondary)
						.padding(.trailing, 4)
				}
			}
		}
		.padding(.vertical, verticalPadding)
		.onAppear {
			articleIconImageLoader.loadImage(for: timelineItem.article)
		}
		.contextMenu {
			TimelineContextMenu(timelineItem: timelineItem)
		}
    }
}
