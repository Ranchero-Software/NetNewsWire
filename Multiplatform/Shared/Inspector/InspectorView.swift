//
//  InspectorView.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 18/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import RSCore
import Account

struct InspectorView: View {
	
	@Environment(\.presentationMode) var presentationMode
	@StateObject private var feedIconImageLoader = FeedIconImageLoader()
	@State private var editedName: String = ""
	@State private var shouldUpdate: Bool = false
	var sidebarItem: SidebarItem
	
	@ViewBuilder
	var body: some View {
		switch sidebarItem.representedType {
		case .webFeed:
			WebFeedInspectorView
				.modifier(InspectorPlatformModifier(shouldUpdate: $shouldUpdate))
		case .folder:
			FolderInspectorView
				.modifier(InspectorPlatformModifier(shouldUpdate: $shouldUpdate))
		case .account:
			AccountInspectorView
				.modifier(InspectorPlatformModifier(shouldUpdate: $shouldUpdate))
		default:
			EmptyView()
		}
	}
	
	@ViewBuilder
	var WebFeedInspectorView: some View {
		Form {
			Section(header: Text("Name").bold()) {
				HStack(alignment: .center) {
					if let image = feedIconImageLoader.image {
						IconImageView(iconImage: image)
							.frame(width: 30, height: 30)
					}
					TextField("", text: $editedName)
				}
			}
			
			#if os(macOS)
			Divider()
			#endif
			
			Section(header: Text("Home Page URL").bold()) {
				Text((sidebarItem.feed as? WebFeed)?.homePageURL ?? "")
			}
			
			#if os(macOS)
			Divider()
			#endif
			
			Section(header: Text("Feed URL").bold()) {
				Text((sidebarItem.feed as? WebFeed)?.url ?? "")
			}
			
			#if os(macOS)
			HStack {
				Spacer()
				Button("Cancel", action: {
					presentationMode.wrappedValue.dismiss()
				})
				Button("Done", action: {
					shouldUpdate = true
				})
			}.padding(.top)
			#endif
		}
		.onAppear {
			editedName = sidebarItem.nameForDisplay
			feedIconImageLoader.loadImage(for: sidebarItem.feed!)
		}.onChange(of: shouldUpdate) { value in
			if value == true {
				if editedName.trimmingWhitespace.count > 0  {
					(sidebarItem.feed as? WebFeed)?.editedName = editedName
				} else {
					(sidebarItem.feed as? WebFeed)?.editedName = nil
				}
				presentationMode.wrappedValue.dismiss()
			}
		}
		
	}
	
	@ViewBuilder
	var FolderInspectorView: some View {
		
		Form {
			Section(header: Text("Name").bold()) {
				HStack(alignment: .center) {
					if let image = feedIconImageLoader.image {
						IconImageView(iconImage: image)
							.frame(width: 30, height: 30)
					}
					TextField("", text: $editedName)
				}
			}
			
			#if os(macOS)
			HStack {
				Spacer()
				Button("Cancel", action: {
					presentationMode.wrappedValue.dismiss()
				})
				Button("Done", action: {
					shouldUpdate = true
				})
			}.padding(.top)
			#endif
			
		}
		.onAppear {
			editedName = sidebarItem.nameForDisplay
			feedIconImageLoader.loadImage(for: sidebarItem.feed!)
		}
		.onChange(of: shouldUpdate) { value in
			if value == true {
				if editedName.trimmingWhitespace.count > 0  {
					(sidebarItem.feed as? Folder)?.name = editedName
				} else {
					(sidebarItem.feed as? Folder)?.name = nil
				}
				presentationMode.wrappedValue.dismiss()
			}
		}
	}
	
	@ViewBuilder
	var AccountInspectorView: some View {
		Form {
			Section(header: Text("Name").bold()) {
				HStack(alignment: .center) {
					if let image = (sidebarItem.represented as? Account)?.smallIcon?.image {
						Image(rsImage: image)
							.resizable()
							.aspectRatio(contentMode: .fit)
							.frame(width: 30, height: 30)
					}
					TextField("", text: $editedName)
				}
			}
			
			#if os(macOS)
			HStack {
				Spacer()
				Button("Cancel", action: {
					presentationMode.wrappedValue.dismiss()
				})
				Button("Done", action: {
					shouldUpdate = true
				})
			}.padding(.top)
			#endif
		}
		.onAppear {
			editedName = sidebarItem.nameForDisplay
		}.onChange(of: shouldUpdate) { value in
			if value == true {
				if editedName.trimmingWhitespace.count > 0  {
					(sidebarItem.represented as? Account)?.name = editedName
				} else {
					(sidebarItem.represented as? Account)?.name = nil
				}
				presentationMode.wrappedValue.dismiss()
			}
		}
	}
	
}


