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
				.containerBackground(for: .widget) {
					Color.clear
				}
		})
		.configurationDisplayName(Text("label.text.unread", comment: "Unread"))
		.description(Text("label.text.unread-widget-description", comment: "A description of the Unread widget."))
		.supportedFamilies([.systemMedium, .systemLarge])
	}
}

struct TodayWidget: Widget {
	let kind: String = "com.ranchero.NetNewsWire.TodayWidget"

	var body: some WidgetConfiguration {

		return StaticConfiguration(kind: kind, provider: Provider(), content: { entry in
			TodayWidgetView(entry: entry)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.containerBackground(for: .widget) {
					Color.clear
				}
		})
		.configurationDisplayName(Text("label.text.today", comment: "Today"))
		.description(Text("label.text.today-widget-description", comment: "A description of the Today widget."))
		.supportedFamilies([.systemMedium, .systemLarge])
	}
}

struct StarredWidget: Widget {
	let kind: String = "com.ranchero.NetNewsWire.StarredWidget"

	var body: some WidgetConfiguration {

		return StaticConfiguration(kind: kind, provider: Provider(), content: { entry in
			StarredWidgetView(entry: entry)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.containerBackground(for: .widget) {
					Color.clear
				}
		})
		.configurationDisplayName(Text("label.text.starred", comment: "Starred"))
		.description(Text("label.text.starred-widget-description", comment: "A description of the Starred widget."))
		.supportedFamilies([.systemMedium, .systemLarge])
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
