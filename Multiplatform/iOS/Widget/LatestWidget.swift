//
//  LatestWidget.swift
//  Widget
//
//  Created by Stuart Breckenridge on 10/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    public typealias Entry = SummaryEntry
	

    public func snapshot(with context: Context, completion: @escaping (SummaryEntry) -> ()) {
		
		if context.isPreview {
			let entry = SummaryEntry(date: Date(),
									 widgetData: WidgetDataDecoder.sampleData())
			completion(entry)
		} else {
			do {
				let widgetData = try WidgetDataDecoder.decodeWidgetData()
				let entry = SummaryEntry(date: Date(), widgetData: widgetData)
				completion(entry)
			} catch {
				let entry = SummaryEntry(date: Date(),
										 widgetData: WidgetData(currentUnreadCount: 42, currentTodayCount: 42, latestArticles: [], lastUpdateTime: Date()))
				completion(entry)
			}
		}
    }

    public func timeline(with context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        
		// Create current timeline entry for now.
		let date = Date()
		var entry: SummaryEntry
		
		do {
			let widgetData = try WidgetDataDecoder.decodeWidgetData()
			entry = SummaryEntry(date: date, widgetData: widgetData)
		} catch {
			entry = SummaryEntry(date: date, widgetData: WidgetData(currentUnreadCount: 42, currentTodayCount: 42, latestArticles: [], lastUpdateTime: Date()))
		}

		// Configure next update in 1 hour.
		let nextUpdateDate = Calendar.current.date(byAdding: .hour, value: 1, to: date)!
		
		let timeline = Timeline(
					entries:[entry],
					policy: .after(nextUpdateDate))
        
        completion(timeline)
    }
}

struct SummaryEntry: TimelineEntry {
    public let date: Date
	public let widgetData: WidgetData
}

struct PlaceholderView : View {
	
	@Environment(\.widgetFamily) var family: WidgetFamily
	
    var body: some View {
        Text("Placeholder View")
    }
}

struct NetNewsWireWidgetView : View {
    
	@Environment(\.widgetFamily) var family: WidgetFamily
	var entry: Provider.Entry

    @ViewBuilder var body: some View {
		switch family {
		case .systemSmall:
			compactWidget
		case .systemMedium:
			mediumWidget
		case .systemLarge:
			compactWidget
		@unknown default:
			compactWidget
		}
    }
	
	var compactWidget: some View {
		VStack(alignment: .leading) {
			Spacer()
			// Today
			HStack(alignment: .firstTextBaseline)  {
				Image(systemName: "sun.max.fill")
					.foregroundColor(.orange)
					.font(.title3)
				VStack(alignment: .leading) {
					Text("Today")
						.font(.title3)
						.bold()
						.foregroundColor(.white)
					Text(String(entry.widgetData.currentTodayCount))
						.font(.body)
						.bold()
						.foregroundColor(.white)
				}
				Spacer()
			}
			// Unread
			HStack(alignment: .firstTextBaseline) {
				Image(systemName: "largecircle.fill.circle")
					.foregroundColor(.accentColor)
					.font(.title3)
				VStack(alignment: .leading) {
					Text("Unread")
						.font(.title3)
						.bold()
						.foregroundColor(.white)
						
					Text(String(entry.widgetData.currentUnreadCount))
						.font(.body)
						.bold()
						.foregroundColor(.white)
				}
				Spacer()
			}
			Spacer()
		}
		.padding()
		.background(Color("WidgetBackground"))
	}
	
	var mediumWidget: some View {
		VStack(alignment: .leading) {
			HStack {
				Text("LATEST UNREAD ARTICLES")
					.font(.headline)
					.foregroundColor(.white)
				Spacer()
			}
			if entry.widgetData.latestArticles.count > 2 {
					VStack(alignment: .leading) {
						ForEach(0..<2, content: { i in
						HStack(alignment: .top) {
							Image(uiImage: thumbnail(entry.widgetData.latestArticles[i].feedIcon))
								.resizable()
								.frame(width: 20, height: 20)
							VStack(alignment: .leading) {
								Text(entry.widgetData.latestArticles[i].articleTitle ?? "")
									.font(.headline)
									.foregroundColor(.white)
								Text(entry.widgetData.latestArticles[i].feedTitle)
									.font(.footnote)
									.foregroundColor(.gray)
								Spacer()
							}
							Spacer()
						}
						})
					}
					
				
			} else {
				ForEach(0..<entry.widgetData.latestArticles.count, content: { i in
					Text(entry.widgetData.latestArticles[i].articleTitle ?? "").font(.headline)
					Text(entry.widgetData.latestArticles[i].feedTitle)
						.font(.footnote)
				})
			}
			Spacer()
		}.padding()
		.background(Color("WidgetBackground"))
	}
	
	func thumbnail(_ data: Data?) -> UIImage {
		if data == nil {
			return UIImage(systemName: "globe")!
		} else {
			return UIImage(data: data!)!
		}
	}
	
}

@main
struct LatestWidget: Widget {
    private let kind: String = "com.ranchero.NetNewsWire.widget"

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind,
							provider: Provider(),
							placeholder: PlaceholderView()) { entry in
            NetNewsWireWidgetView(entry: entry)
        }
        .configurationDisplayName("NetNewsWire")
        .description("NetNewsWire")
		.supportedFamilies([.systemSmall, .systemMedium])
		
    }
}

struct Widget_Previews: PreviewProvider {
    static var previews: some View {
		NetNewsWireWidgetView(entry: SummaryEntry(date: Date(), widgetData: WidgetDataDecoder.sampleData()))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
