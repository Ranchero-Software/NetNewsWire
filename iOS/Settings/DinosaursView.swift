//
//  DinosaursView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 09/06/2026.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import SwiftUI
import RSCore

struct DinosaursView: View {

	private static let helpURL = URL(string: "https://netnewswire.com/help/dinosaurs.html")!

	// MARK: State
	@State private var model = DinosaursViewModel()
	@State private var dinosaurPendingDeletion: DinosaurRow?
	@State private var showDeleteConfirmation = false
	@State private var showHelp = false
	@State private var homePageURL: HomePageURL?

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
									Text("Go to Feed", comment: "Go to Feed")
									Image(systemName: "arrow.up.right")
								}
								Button {
									guard let homePage = dinosaur.feed.homePageURL,
										  let url = URL(string: homePage) else {
										return
									}
									homePageURL = HomePageURL(url: url)
								} label: {
									Text("Open Home Page", comment: "Command")
									Image(systemName: "safari")
								}

								Button {
									UIPasteboard.general.string = dinosaur.feedURL
								} label: {
									Text("Copy Feed URL", comment: "Command")
									Image(systemName: "document.on.document")
								}
							} label: {
								Label("More", systemImage: "ellipsis")
							}
							.labelStyle(.iconOnly)
							.help("Menu: Go to Feed, Open Home Page, Copy Feed URL")
						}
				}
			} header: {
				VStack(alignment: .leading) {
					Text("Show feeds that haven’t updated in…", comment: "Show stale feeds text")
						.font(.subheadline)
						.foregroundStyle(Color.primary)
					Picker("", selection: $model.monthThreshold) {
						ForEach([3, 6, 12, 24], id: \.self) { month in
							Text("\(month) months", comment: "Dinosaur staleness threshold in months").tag(month)
						}
					}
					.pickerStyle(.segmented)
					.padding(.bottom, 12)
					.onChange(of: model.monthThreshold) {
						Task { @MainActor in
							await model.refresh()
						}
					}
				}
			} footer: {
				if model.rows.count == 0 {
					Text("No dinosaurs", comment: "No dinosaurs footer text.")
				} else {
					Text("Swipe a feed to show the action menu and delete button.", comment: "Dinosaurs swipe hint.")
						.padding(.top, 8)
				}
			}

			Section {
			} footer: {
				helpLinkFooter
			}
		}
		.navigationTitle("🦖 Dinosaurs")
		.navigationBarTitleDisplayMode(.inline)
		.task {
			model.sortBy(.lastArticleDate, ascending: true)
			await model.refresh()
		}
		.sheet(isPresented: $showHelp) {
			SafariView(url: Self.helpURL)
		}
		.sheet(item: $homePageURL) { homePageURL in
			SafariView(url: homePageURL.url)
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
				Text("Delete", comment: "Delete button")
			}
		}, message: {
			Text("Are you sure you want to delete the feed ”\(dinosaurPendingDeletion?.feedName ?? "")”?", comment: "Delete feed confirmation text.")
		})

	}
}

// MARK: - Private

private extension DinosaursView {

	var helpLinkFooter: some View {
		Button(NSLocalizedString("Dinosaurs Help", comment: "Help link")) {
			showHelp = true
		}
		.font(.subheadline)
		.frame(maxWidth: .infinity)
		.padding(.top, 8)
	}
}

private struct HomePageURL: Identifiable {

	let url: URL

	var id: String { url.absoluteString }
}
