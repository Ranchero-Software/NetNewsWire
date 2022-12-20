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
			Section(header: Text("INSTALLED_THEMES", tableName: "Settings")) {
				articleThemeRow("Default")
				ForEach(themeManager.themeNames, id: \.self) {theme in
					articleThemeRow(theme)
				}
			}
		}
		.navigationTitle(Text("ARTICLE_THEMES_TITLE", tableName: "Settings"))
		.toolbar {
			ToolbarItem(placement: .navigationBarTrailing) {
				Button {
					showImportThemeView = true
				} label: {
					Label {
						Text("IMPORT_THEME_BUTTON_TITLE", tableName: "Buttons")
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
					let theme = try ArticleTheme(path: success.path, isAppTheme: true)
					showImportConfirmationAlert = (theme, true)
				} catch {
					showImportErrorAlert = (error, true)
				}
			case .failure(let failure):
				showImportErrorAlert = (failure, true)
			}
		}
		.alert(Text("DELETE_THEME_ALERT_TITLE_\(showDeleteConfirmation.0)", tableName: "Settings"), isPresented: $showDeleteConfirmation.1, actions: {
			Button(role: .destructive) {
				ArticleThemesManager.shared.deleteTheme(themeName: showDeleteConfirmation.0)
			} label: {
				Text("DELETE_THEME_BUTTON_TITLE", tableName: "Buttons")
			}
			
			Button(role: .cancel) {
				
			} label: {
				Text("CANCEL_BUTTON_TITLE", tableName: "Buttons")
			}
		}, message: {
			Text("DELETE_THEME_ALERT_MESSAGE", tableName: "Settings")
		})
		.alert(Text("IMPORT_THEME_CONFIRMATION_TITLE", tableName: "Settings"),
			   isPresented: $showImportConfirmationAlert.1,
			   actions: {
					Button {
						do {
							try ArticleThemesManager.shared.importTheme(filename: showImportConfirmationAlert.0!.path!)
							showImportSuccessAlert = true
						} catch {
							showImportErrorAlert = (error, true)
						}
						
					} label: {
						Text("IMPORT_THEME_BUTTON_TITLE", tableName: "Buttons")
					}
					
					Button(role: .cancel) {
						
					} label: {
						Text("CANCEL_BUTTON_TITLE", tableName: "Buttons")
					}
		}, message: {
			Text("IMPORT_THEME_CONFIRMATION_MESSAGE_\(showImportConfirmationAlert.0?.name ?? "")_\(showImportConfirmationAlert.0?.creatorName ?? "")", tableName: "Settings")
		})
		.alert(Text("IMPORT_THEME_SUCCESS_TITLE", tableName: "Settings"),
			   isPresented: $showImportSuccessAlert,
			   actions: {
					Button(role: .cancel) {
						
					} label: {
						Text("DISMISS_BUTTON_TITLE", tableName: "Buttons")
					}
		}, message: {
			Text("IMPORT_THEME_SUCCESS_MESSAGE_\(showImportConfirmationAlert.0?.name ?? "")", tableName: "Settings")
		})
    }
	
	func articleThemeRow(_ theme: String) -> some View {
		Button {
			ArticleThemesManager.shared.currentThemeName = theme
		} label: {
			HStack {
				Text(theme)
					.foregroundColor(.primary)
				Spacer()
				if ArticleThemesManager.shared.currentThemeName == theme {
					Image(systemName: "checkmark")
						.foregroundColor(Color(uiColor: AppAssets.primaryAccentColor))
				}
			}
		}
		.swipeActions(edge: .trailing, allowsFullSwipe: false) {
			if theme == "Default" || ArticleThemesManager.shared.currentThemeName == theme {  }
			else {
				Button {
					showDeleteConfirmation = (theme, true)
				} label: {
					Text("DELETE_BUTTON_TITLE", tableName: "Buttons")
					Image(systemName: "trash")
				}
				.tint(.red)
			}
		}
	}
}

struct ArticleThemeImporterView_Previews: PreviewProvider {
    static var previews: some View {
        ArticleThemeManagerView()
    }
}
