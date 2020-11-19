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
		.configurationDisplayName("Your Unread Articles")
		.description("A sneak peak at what's left unread.")
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
		.configurationDisplayName("Your Today Articles")
		.description("A sneak peak at unread recently published articles.")
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
		.configurationDisplayName("Your Starred Articles")
		.description("A sneak peak at your starred articles.")
		.supportedFamilies([.systemMedium, .systemLarge])
		
	}
}

struct SmartFeedSummaryWidget: Widget {
	let kind: String = "com.ranchero.NetNewsWire.SmartFeedSummaryWidget"
	
	var body: some WidgetConfiguration {
		
		return StaticConfiguration(kind: kind, provider: Provider(), content: { entry in
			SmartFeedSummaryWidgetView(entry: entry)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.background(Color("WidgetBackground"))
			
		})
		.configurationDisplayName("Your Smart Feed Summary")
		.description("A count of your smart feeds.")
		.supportedFamilies([.systemSmall])
		
	}
}


// MARK: - WidgetBundle
@main
struct NetNewsWireWidgets: WidgetBundle {
	@WidgetBundleBuilder
	var body: some Widget {
		SmartFeedSummaryWidget()
		UnreadWidget()
		TodayWidget()
		StarredWidget()
	}
}
