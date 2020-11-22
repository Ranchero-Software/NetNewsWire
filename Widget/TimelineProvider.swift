//
//  TimelineProvider.swift
//  NetNewsWire Widget Extension
//
//  Created by Stuart Breckenridge on 18/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
	
	func placeholder(in context: Context) -> WidgetTimelineEntry {
		do {
			let data = try WidgetDataDecoder.decodeWidgetData()
			return WidgetTimelineEntry(date: Date(), widgetData: data)
		} catch {
			return WidgetTimelineEntry(date: Date(), widgetData: WidgetDataDecoder.sampleData())
		}
	}
	
	func getSnapshot(in context: Context, completion: @escaping (WidgetTimelineEntry) -> Void) {
		if context.isPreview {
			do {
				let data = try WidgetDataDecoder.decodeWidgetData()
				completion(WidgetTimelineEntry(date: Date(), widgetData: data))
			} catch {
				completion(WidgetTimelineEntry(date: Date(),
											   widgetData: WidgetDataDecoder.sampleData()))
			}
		} else {
			do {
				let widgetData = try WidgetDataDecoder.decodeWidgetData()
				let entry = WidgetTimelineEntry(date: Date(), widgetData: widgetData)
				completion(entry)
			} catch {
				let entry = WidgetTimelineEntry(date: Date(),
												widgetData: WidgetDataDecoder.sampleData())
				completion(entry)
			}
		}
	}
	
	func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetTimelineEntry>) -> Void) {
		// Create current timeline entry for now.
		let date = Date()
		var entry: WidgetTimelineEntry
		
		do {
			let widgetData = try WidgetDataDecoder.decodeWidgetData()
			entry = WidgetTimelineEntry(date: date, widgetData: widgetData)
		} catch {
			entry = WidgetTimelineEntry(date: date, widgetData: WidgetData(currentUnreadCount: 0, currentTodayCount: 0, currentStarredCount: 0, unreadArticles: [], starredArticles: [], todayArticles: [], lastUpdateTime: Date()))
		}
		
		// Configure next update in 1 hour.
		let nextUpdateDate = Calendar.current.date(byAdding: .hour, value: 1, to: date)!
		
		let timeline = Timeline(
			entries:[entry],
			policy: .after(nextUpdateDate))
		
		completion(timeline)
	}
	
	public typealias Entry = WidgetTimelineEntry
	
}

struct WidgetTimelineEntry: TimelineEntry {
	public let date: Date
	public let widgetData: WidgetData
}

