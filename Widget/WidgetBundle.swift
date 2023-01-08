//
//  WidgetBundle.swift
//  NetNewsWire Widget Extension
//
//  Created by Stuart Breckenridge on 18/11/2020.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import WidgetKit
import SwiftUI

// MARK: - Supported Widgets

struct UnreadWidget: Widget {
	let kind: String = "com.ranchero.NetNewsWire.UnreadWidget"
	
	var body: some WidgetConfiguration {
		
		return StaticConfiguration(kind: kind, provider: Provider(), content: { entry in
			UnreadWidgetView(entry: entry)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.background(Color("WidgetBackground"))
			
		})
		.configurationDisplayName(Text("widget.title.unread", comment: "Your Unread Articles"))
		.description(Text("widget.description.unread", comment: "A sneak peek at your unread articles."))
		.supportedFamilies([.systemMedium, .systemLarge])
		
	}
}

struct TodayWidget: Widget {
	let kind: String = "com.ranchero.NetNewsWire.TodayWidget"
	
	var body: some WidgetConfiguration {
		
		return StaticConfiguration(kind: kind, provider: Provider(), content: { entry in
			TodayWidgetView(entry: entry)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.background(Color("WidgetBackground"))
			
		})
		.configurationDisplayName(Text("widget.title.today", comment: "Your Today Articles"))
		.description(Text("widget.description.today", comment: "A sneak peek at recently published unread articles."))
		.supportedFamilies([.systemMedium, .systemLarge])
		
	}
}

struct StarredWidget: Widget {
	let kind: String = "com.ranchero.NetNewsWire.StarredWidget"
	
	var body: some WidgetConfiguration {
		
		return StaticConfiguration(kind: kind, provider: Provider(), content: { entry in
			StarredWidgetView(entry: entry)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.background(Color("WidgetBackground"))
			
		})
		.configurationDisplayName(Text("widget.title.starred", comment: "Your Starred Articles"))
		.description(Text("widget.description.starred", comment: "A sneak peek at your starred articles."))
		.supportedFamilies([.systemMedium, .systemLarge])
		
	}
}


@available(iOSApplicationExtension 16.0, *)
struct SmartFeedSummaryWidget: Widget {
	let kind: String = "com.ranchero.NetNewsWire.SmartFeedSummaryWidget"
	
	var body: some WidgetConfiguration {
		
		return StaticConfiguration(kind: kind, provider: Provider(), content: { entry in
			SmartFeedSummaryWidgetView(entry: entry)
		})
		.configurationDisplayName(Text("widget.title.smart-feed-summary", comment: "Your Smart Feed Summary"))
		.description(Text("widget.description.smart-feed-summary", comment: "Your smart feeds, summarized."))
		.supportedFamilies([.accessoryRectangular])
	}
}

// MARK: - WidgetBundle
@main
struct NetNewsWireWidgets: WidgetBundle {
	@WidgetBundleBuilder
	var body: some Widget {
		widgets()
	}
	
	func widgets() -> some Widget {
		if #available(iOS 16.0, *) {
			return WidgetBundleBuilder.buildBlock(UnreadWidget(), TodayWidget(), StarredWidget(), SmartFeedSummaryWidget())
		} else {
			return WidgetBundleBuilder.buildBlock(UnreadWidget(), TodayWidget(), StarredWidget())
		}
	}
	
}
