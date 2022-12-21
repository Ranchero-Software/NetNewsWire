//
//  ArticleThemeManagerView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 20/12/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI

struct ArticleThemeManagerView: View {
    
	@StateObject private var themeManager = ArticleThemesManager.shared
	@State private var showDeleteConfirmation: (String, Bool) = ("", false)
	@State private var showImportThemeView: Bool = false
	@State private var showImportConfirmationAlert: (ArticleTheme?, Bool) = (nil, false)
	@State private var showImportErrorAlert: (Error?, Bool) = (nil, false)
	@State private var showImportSuccessAlert: Bool = false
	
	var body: some View {
		Form {
			Section(header: Text("Installed Themes", comment: "Section header for installed themes")) {
				articleThemeRow("Default")
				ForEach(themeManager.themeNames, id: \.self) {theme in
					articleThemeRow(theme)
				}
			}
		}
		.navigationTitle(Text("Article Themes", comment: "Navigation bar title for Article Themes"))
		.toolbar {
			ToolbarItem(placement: .navigationBarTrailing) {
				Button {
					showImportThemeView = true
				} label: {
					Label {
						Text("Import Theme", comment: "Button title")
					} icon: {
						Image(systemName: "plus")
					}
				}
			}
		}
		.fileImporter(isPresented: $showImportThemeView, allowedContentTypes: NNWThemeDocument.readableContentTypes) { result in
			switch result {
			case .success(let success):
				do {
					let url = URL(fileURLWithPath: success.path)
					if url.startAccessingSecurityScopedResource() {
						let theme = try ArticleTheme(path: success.path, isAppTheme: false)
						showImportConfirmationAlert = (theme, true)
						url.stopAccessingSecurityScopedResource()
					}
				} catch {
					showImportErrorAlert = (error, true)
				}
			case .failure(let failure):
				showImportErrorAlert = (failure, true)
			}
		}
		.alert(Text("Are you sure you want to delete “\(showDeleteConfirmation.0)”?", comment: "Alert title: confirm theme deletion"),
			   isPresented: $showDeleteConfirmation.1, actions: {
			Button(role: .destructive) {
				themeManager.deleteTheme(themeName: showDeleteConfirmation.0)
			} label: {
				Text("Delete Theme", comment: "Button title")
			}
			
			Button(role: .cancel) {
				
			} label: {
				Text("Cancel", comment: "Button title")
			}
		}, message: {
			Text("Are you sure you want to delete this theme? This action cannot be undone.", comment: "Alert message: confirm theme deletion")
		})
		.alert(Text("Import Theme", comment: "Alert title: confirm theme import"),
			   isPresented: $showImportConfirmationAlert.1,
			   actions: {
					Button {
						do {
							if themeManager.themeExists(filename: showImportConfirmationAlert.0!.path!) {
								if try! themeManager.articleThemeWithThemeName(showImportConfirmationAlert.0!.name).isAppTheme {
									showImportErrorAlert = (LocalizedNetNewsWireError.duplicateDefaultTheme, true)
								} else {
									try themeManager.importTheme(filename: showImportConfirmationAlert.0!.path!)
									showImportSuccessAlert = true
								}
							} else {
								try themeManager.importTheme(filename: showImportConfirmationAlert.0!.path!)
								showImportSuccessAlert = true
							}
						} catch {
							showImportErrorAlert = (error, true)
						}
					} label: {
						let exists = themeManager.themeExists(filename: showImportConfirmationAlert.0?.path ?? "")
						if exists == true {
							Text("Overwrite", comment: "Button title")
						} else {
							Text("Import Theme", comment: "Button title")
						}
					}
					
					Button(role: .cancel) {
						
					} label: {
						Text("Cancel", comment: "Button title")
					}
		}, message: {
			let exists = themeManager.themeExists(filename: showImportConfirmationAlert.0?.path ?? "")
			if exists {
				Text("The theme “\(showImportConfirmationAlert.0?.name ?? "")” already exists. Do you want to overwrite it?", comment: "Alert message: confirm theme import and overwrite of existing theme")
			} else {
				Text("Are you sure you want to import “\(showImportConfirmationAlert.0?.name ?? "")” by \(showImportConfirmationAlert.0?.creatorName ?? "")?", comment: "Alert message: confirm theme import")
			}
		})
		.alert(Text("Imported Successfully", comment: "Alert title: theme imported successfully"),
			   isPresented: $showImportSuccessAlert,
			   actions: {
					Button(role: .cancel) {
						
					} label: {
						Text("Dismiss", comment: "Button title")
					}
		}, message: {
			Text("The theme “\(showImportConfirmationAlert.0?.name ?? "")” has been imported.", comment: "Alert message: theme imported successfully")
		})
		.alert(Text("Error", comment: "Alert title: Error"),
			   isPresented: $showImportErrorAlert.1,
			   actions: {
					Button(role: .cancel) {
						
					} label: {
						Text("Dismiss", comment: "Button title")
					}
		}, message: {
			Text("\(showImportErrorAlert.0?.localizedDescription ?? "")")
		})
    }
	
	func articleThemeRow(_ theme: String) -> some View {
		Button {
			themeManager.currentThemeName = theme
		} label: {
			HStack {
				VStack(alignment: .leading) {
					Text(theme)
						.foregroundColor(.primary)
					if let articleTheme = try? themeManager.articleThemeWithThemeName(theme) {
						Text("Created by \(articleTheme.creatorName)", comment: "Article theme creator byline.")
							.font(.caption)
							.foregroundColor(.secondary)
					}
				}
				Spacer()
				if themeManager.currentThemeName == theme {
					Image(systemName: "checkmark")
						.foregroundColor(Color(uiColor: AppAssets.primaryAccentColor))
				}
			}
			
		}
		.swipeActions(edge: .trailing, allowsFullSwipe: false) {
			if theme == themeManager.currentThemeName { }
			if let currentTheme = try? themeManager.articleThemeWithThemeName(theme) {
				if currentTheme.isAppTheme { } else {
					Button {
						showDeleteConfirmation = (theme, true)
					} label: {
						Text("Delete", comment: "Button title")
						Image(systemName: "trash")
					}
					.tint(.red)
				}
			}
		}
	}
}

struct ArticleThemeImporterView_Previews: PreviewProvider {
    static var previews: some View {
        ArticleThemeManagerView()
    }
}
