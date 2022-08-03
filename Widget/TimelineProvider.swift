//
//  TimelineProvider.swift
//  NetNewsWire Widget Extension
//
//  Created by Stuart Breckenridge on 18/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import WidgetKit
import SwiftUI
import RSCore

struct Provider: TimelineProvider, Logging {
	
	let decoder = WidgetDataDecoder()
	
	func placeholder(in context: Context) -> WidgetTimelineEntry {
		do {
			let data = try decoder.decodeWidgetData()
			return WidgetTimelineEntry(date: Date(), widgetData: data)
		} catch {
			logger.error("Failed to decode widget data: \(error.localizedDescription, privacy: .public)")
			return WidgetTimelineEntry(date: Date(), widgetData: decoder.sampleData())
		}
	}
	
	func getSnapshot(in context: Context, completion: @escaping (WidgetTimelineEntry) -> Void) {
		if context.isPreview {
			do {
				let data = try decoder.decodeWidgetData()
				completion(WidgetTimelineEntry(date: Date(), widgetData: data))
			} catch {
				logger.error("Failed to decode widget data: \(error.localizedDescription, privacy: .public)")
				completion(WidgetTimelineEntry(date: Date(),
											   widgetData: decoder.sampleData()))
			}
		} else {
			do {
				let widgetData = try decoder.decodeWidgetData()
				let entry = WidgetTimelineEntry(date: Date(), widgetData: widgetData)
				completion(entry)
			} catch {
				logger.error("Failed to decode widget data: \(error.localizedDescription, privacy: .public)")
				let entry = WidgetTimelineEntry(date: Date(),
												widgetData: decoder.sampleData())
				completion(entry)
			}
		}
	}
	
	func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetTimelineEntry>) -> Void) {
		// Create current timeline entry for now.
		let date = Date()
		var entry: WidgetTimelineEntry
		
		do {
			let widgetData = try decoder.decodeWidgetData()
			entry = WidgetTimelineEntry(date: date, widgetData: widgetData)
		} catch {
			logger.error("Failed to decode widget data: \(error.localizedDescription, privacy: .public)")
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

