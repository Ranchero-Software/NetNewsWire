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
		.configurationDisplayName(L10n.unreadWidgetTitle)
		.description(L10n.unreadWidgetDescription)
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
		.configurationDisplayName(L10n.todayWidgetTitle)
		.description(L10n.todayWidgetDescription)
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
		.configurationDisplayName(L10n.starredWidgetTitle)
		.description(L10n.starredWidgetDescription)
		.supportedFamilies([.systemMedium, .systemLarge])
		
	}
}

struct SmartFeedSummaryWidget: Widget {
	let kind: String = "com.ranchero.NetNewsWire.SmartFeedSummaryWidget"
	
	var body: some WidgetConfiguration {
		
		return StaticConfiguration(kind: kind, provider: Provider(), content: { entry in
			SmartFeedSummaryWidgetView(entry: entry)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.background(Color("AccentColor"))
			
		})
		.configurationDisplayName(L10n.smartFeedSummaryWidgetTitle)
		.description(L10n.smartFeedSummaryWidgetDescription)
		.supportedFamilies([.systemSmall])
		
	}
}


// MARK: - WidgetBundle
@main
struct NetNewsWireWidgets: WidgetBundle {
	@WidgetBundleBuilder
	var body: some Widget {
		UnreadWidget()
		TodayWidget()
		StarredWidget()
	}
}
