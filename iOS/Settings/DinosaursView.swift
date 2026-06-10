//
//  DinosaursView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 09/06/2026.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import SwiftUI

struct DinosaursView: View {
	
	// MARK: State
	@State private var model = DinosaursViewModel()
	@State private var dinosaurPendingDeletion: DinosaurRow? = nil
	@State private var showDeleteConfirmation = false
	
	// MARK: Constants
	let dismissAndPresent: (_ dinosaur: DinosaurRow) -> Void
	
	
	var body: some View {
		List {
			Section {
				ForEach(model.rows) { dinosaur in
					DinosaurRowView(dinosaur: dinosaur)
						.swipeActions(edge: .trailing, allowsFullSwipe: false) {
							Button {
								dinosaurPendingDeletion = dinosaur
								showDeleteConfirmation = true
							} label: {
								Image(systemName: "trash")
							}
							.tint(.red)
							.help("Delete Feed")
							
							Menu {
								Button {
									dismissAndPresent(dinosaur)
								} label: {
									Text("Show Feed", comment: "Show Feed")
									Image(systemName: "arrow.up.right")
								}
								Button {
									guard let homePage = dinosaur.feed.homePageURL,
										  let url = URL(string: homePage) else { return }
									UIApplication.shared.open(url)
								} label: {
									Text("Open Home Page", comment: "Open Home Page")
									Image(systemName: "safari")
								}
								
								Button {
									UIPasteboard.general.string = dinosaur.feedURL
								} label: {
									Text("Copy Feed URL", comment: "Copy Feed URL")
									Image(systemName: "document.on.document")
								}
							} label: {
								Image(systemName: "ellipsis")
							}
							.help("Menu: Show Feed, Open Home Page, Copy Feed URL")
						}
				}
			} header: {
				VStack(alignment: .leading) {
					Text("Show feeds that haven’t updated in…", comment: "Show stale feeds text")
						.font(.subheadline)
					Picker("", selection: $model.monthThreshold) {
						ForEach([3,6,12,24], id: \.self) { month in
							Text("\(month) months", comment: "Dinosaur staleness threshold in months").tag(month)
						}
					}
					.pickerStyle(.segmented)
					.onChange(of: model.monthThreshold) {
						Task { @MainActor in
							await model.refresh()
						}
					}
				}
			} footer: {
				if model.rows.count == 0 {
					Text("There are no dinosaurs. All feeds have published articles within the last \(model.monthThreshold) months.", comment: "No dinosaurs footer text.")
				}
			}
		}
		.navigationTitle("🦖 Dinosaurs")
		.navigationBarTitleDisplayMode(.inline)
		.task {
			await model.refresh()
		}
		.alert("Delete Feed", isPresented: $showDeleteConfirmation, actions: {
			Button(role: .destructive) {
				if let dinosaur = dinosaurPendingDeletion {
					let deletion = DinosaurDeletion(feed: dinosaur.feed,
													account: dinosaur.account,
													containers: dinosaur.account.existingContainers(withFeed: dinosaur.feed))
					model.performDeletions([deletion])
					Task { @MainActor in
						await model.refresh()
					}
					dinosaurPendingDeletion = nil
				}
				
			} label: {
				Text("Delete", comment: "Delete")
			}
		}, message: {
			Text("Are you sure you want to delete the feed ”\(dinosaurPendingDeletion?.feedName ?? "")”?", comment: "Delete feed confirmation text.")
		})
		
	}
}





