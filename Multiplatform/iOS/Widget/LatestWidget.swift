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
    public typealias Entry = SimpleEntry

    public func snapshot(with context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    public func timeline(with context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    public let date: Date
}

struct PlaceholderView : View {
    var body: some View {
        Text("Placeholder View")
    }
}

struct WidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        Text(entry.date, style: .time)
    }
}

@main
struct LatestWidget: Widget {
    private let kind: String = "Widget"

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind,
							provider: Provider(),
							placeholder: PlaceholderView()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("NetNewsWire Now")
        .description("This is NetNewsWire.")
		.supportedFamilies([.systemSmall, .systemMedium])
		
    }
}

struct Widget_Previews: PreviewProvider {
    static var previews: some View {
        WidgetEntryView(entry: SimpleEntry(date: Date()))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
