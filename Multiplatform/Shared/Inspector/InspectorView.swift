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
	@StateObject private var inspectorModel = InspectorModel()
	var sidebarItem: SidebarItem
	
	var body: some View {
		switch sidebarItem.representedType {
		case .webFeed:
			WebFeedInspectorView
				.modifier(InspectorPlatformModifier(shouldUpdate: $inspectorModel.shouldUpdate))
		case .folder:
			FolderInspectorView
				.modifier(InspectorPlatformModifier(shouldUpdate: $inspectorModel.shouldUpdate))
		case .account:
			AccountInspectorView
				.modifier(InspectorPlatformModifier(shouldUpdate: $inspectorModel.shouldUpdate))
		default:
			EmptyView()
		}
	}
	
	// MARK: WebFeed Inspector
	
	
	var WebFeedInspectorView: some View {
		Form {
			Section(header: webFeedHeader) {
				TextField("", text: $inspectorModel.editedName)
			}
			
			#if os(macOS)
			Divider()
			#endif
			
			Section(content: {
				Toggle("Notify About New Articles", isOn: $inspectorModel.notifyAboutNewArticles)
				Toggle("Always Show Reader View", isOn: $inspectorModel.alwaysShowReaderView)
			})
			
			if let homePageURL = (sidebarItem.feed as? WebFeed)?.homePageURL {
				#if os(macOS)
				Divider()
				#endif
				
				Section(header: Text("Home Page URL")) {
					HStack {
						Text(verbatim: homePageURL)
							.fixedSize(horizontal: false, vertical: true)
						Spacer()
						AppAssets.openInBrowserImage
							.foregroundColor(.accentColor)
					}
					.onTapGesture {
						if let url = URL(string: homePageURL) {
							#if os(macOS)
							NSWorkspace.shared.open(url)
							#else
							inspectorModel.showHomePage = true
							#endif
						}
					}
					.contextMenu(ContextMenu(menuItems: {
						Button(action: {
							#if os(macOS)
							URLPasteboardWriter.write(urlString: homePageURL, to: NSPasteboard.general)
							#else
							UIPasteboard.general.string = homePageURL
							#endif
						}, label: {
							Text("Copy Home Page URL")
						})
					}))
					.sheet(isPresented: $inspectorModel.showHomePage, onDismiss: { inspectorModel.showHomePage = false }) {
						#if os(macOS)
						EmptyView()
						#else
						SafariView(url: URL(string: (sidebarItem.feed as! WebFeed).homePageURL!)!)
						#endif
					}
				}
			}
			
			#if os(macOS)
			Divider()
			#endif
			
			Section(header: Text("Feed URL")) {
				VStack {
//					#if os(macOS)
//					Spacer() // This shouldn't be necessary, but for some reason macOS doesn't put the space in itself
//					#endif
					Text(verbatim: (sidebarItem.feed as? WebFeed)?.url ?? "")
						.fixedSize(horizontal: false, vertical: true)
						.contextMenu(ContextMenu(menuItems: {
							Button(action: {
								if let urlString = (sidebarItem.feed as? WebFeed)?.url {
									#if os(macOS)
									URLPasteboardWriter.write(urlString: urlString, to: NSPasteboard.general)
									#else
									UIPasteboard.general.string = urlString
									#endif
								}
							}, label: {
								Text("Copy Feed URL")
							})
						}))
				}
			}
			
			#if os(macOS)
			HStack {
				Spacer()
				Button("Cancel", action: {
					presentationMode.wrappedValue.dismiss()
				})
				Button("Done", action: {
					inspectorModel.shouldUpdate = true
				})
			}.padding([.top, .bottom], 20)
			#endif
		}
		.onAppear {
			inspectorModel.configure(with: sidebarItem.feed as! WebFeed)
			feedIconImageLoader.loadImage(for: sidebarItem.feed!)
		}.onReceive(inspectorModel.$shouldUpdate) { value in
			if value == true {
				if inspectorModel.editedName.trimmingWhitespace.count > 0  {
					(sidebarItem.feed as? WebFeed)?.rename(to: inspectorModel.editedName.trimmingWhitespace) { _ in }
				}
				presentationMode.wrappedValue.dismiss()
			}
		}
	}
	
	var webFeedHeader: some View {
		HStack(alignment: .center) {
			Spacer()
			if let image = feedIconImageLoader.image {
				IconImageView(iconImage: image)
					.frame(width: 50, height: 50)
			}
			Spacer()
		}.padding(.top, 20)
	}
	
	
	// MARK: Folder Inspector
	
	var FolderInspectorView: some View {
		Form {
			Section(header: folderHeader) {
				TextField("", text: $inspectorModel.editedName)
			}
			
			#if os(macOS)
			HStack {
				Spacer()
				Button("Cancel", action: {
					presentationMode.wrappedValue.dismiss()
				})
				Button("Done", action: {
					inspectorModel.shouldUpdate = true
				})
			}.padding([.top, .bottom])
			#endif
		}
		.onAppear {
			inspectorModel.configure(with: sidebarItem.represented as! Folder)
			feedIconImageLoader.loadImage(for: sidebarItem.feed!)
		}
		.onReceive(inspectorModel.$shouldUpdate) { value in
			if value == true {
				if inspectorModel.editedName.trimmingWhitespace.count > 0  {
					(sidebarItem.feed as? Folder)?.rename(to: inspectorModel.editedName.trimmingWhitespace) { _ in }
				}
				presentationMode.wrappedValue.dismiss()
			}
		}
	}
	
	var folderHeader: some View {
		HStack(alignment: .center) {
			Spacer()
			if let image = feedIconImageLoader.image {
				IconImageView(iconImage: image)
					.frame(width: 50, height: 50)
			}
			Spacer()
		}.padding(.top, 20)
	}
	
	
	// MARK: Account Inspector
	
	var AccountInspectorView: some View {
		Form {
			Section(header: accountHeader) {
				TextField("", text: $inspectorModel.editedName)
				Toggle("Active", isOn: $inspectorModel.accountIsActive)
			}
			
			#if os(macOS)
			HStack {
				Spacer()
				Button("Cancel", action: {
					presentationMode.wrappedValue.dismiss()
				}).keyboardShortcut(.cancelAction)
				Button("Done", action: {
					inspectorModel.shouldUpdate = true
				}).keyboardShortcut(.defaultAction)
			}.padding(.top)
			#endif
		}
		.onAppear {
			inspectorModel.configure(with: sidebarItem.represented as! Account)
		}
		.onReceive(inspectorModel.$shouldUpdate) { value in
			if value == true {
				if inspectorModel.editedName.trimmingWhitespace.count > 0  {
					(sidebarItem.represented as? Account)?.name = inspectorModel.editedName
				} else {
					(sidebarItem.represented as? Account)?.name = nil
				}
				presentationMode.wrappedValue.dismiss()
			}
		}
	}
	
	var accountHeader: some View {
		HStack(alignment: .center) {
			Spacer()
			if let image = (sidebarItem.represented as? Account)?.smallIcon?.image {
				Image(rsImage: image)
					.resizable()
					.aspectRatio(contentMode: .fit)
					.frame(width: 50, height: 50)
			}
			Spacer()
		}.padding()
	}
	
	
}


