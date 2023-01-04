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
	@State private var installedFirstPartyThemes: [ArticleTheme] = []
	@State private var installedThirdPartyThemes: [ArticleTheme] = []
	
	var body: some View {
		Form {
			Section(header: Text("label.text.default-themes", comment: "Default Themes"), footer: Text("label.text.default-themes-explainer", comment: "These themes cannot be deleted.")) {
				articleThemeRow(try! themeManager.articleThemeWithThemeName("Default"))
				ForEach(0..<installedFirstPartyThemes.count, id: \.self) { i in
					articleThemeRow(installedFirstPartyThemes[i])
				}
			}
			
			Section(header: Text("label.text.third-party-themes", comment: "Third Party Themes")) {
				ForEach(0..<installedThirdPartyThemes.count, id: \.self) { i in
					articleThemeRow(installedThirdPartyThemes[i])
				}
			}
			
		}
		.navigationTitle(Text("navigation.title.article-themes", comment: "Article Themes"))
		.task {
			updateThemesArrays()
		}
		.toolbar {
			ToolbarItem(placement: .navigationBarTrailing) {
				Button {
					showImportThemeView = true
				} label: {
					Label {
						Text("button.title.import-theme", comment: "Import Theme")
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
		.alert(Text("alert.title.delete-theme.\(showDeleteConfirmation.0)", comment: "In English: Are you sure you want to delete “%@”?"),
			   isPresented: $showDeleteConfirmation.1, actions: {
			Button(role: .destructive) {
				themeManager.deleteTheme(themeName: showDeleteConfirmation.0)
			} label: {
				Text("button.title.delete-theme", comment: "Delete Theme")
			}
			
			Button(role: .cancel) {
				
			} label: {
				Text("button.title.cancel", comment: "Cancel")
			}
		}, message: {
			Text("alert.message.cannot-undo-action", comment: "You can't undo this action.")
		})
		.alert(Text("alert.title.import-theme", comment: "Import Theme"),
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
							Text("button.title.overwrite-theme", comment: "Overwrite Theme")
						} else {
							Text("button.title.import-theme", comment: "Import Theme")
						}
					}
					
					Button(role: .cancel) {
						
					} label: {
						Text("button.title.cancel", comment: "Cancel")
					}
		}, message: {
			let exists = themeManager.themeExists(filename: showImportConfirmationAlert.0?.path ?? "")
			if exists {
				Text("alert.message.duplicate-theme.\(showImportConfirmationAlert.0?.name ?? "")", comment: "In English: The theme “%@” already exists. Do you want to overwrite it?")
			} else {
				Text("alert.message.import-theme.\(showImportConfirmationAlert.0?.name ?? "").\(showImportConfirmationAlert.0?.creatorName ?? "")", comment: "Are you sure you want to import “%@” by %@")
			}
		})
		.alert(Text("alert.title.imported-theme-succesfully", comment: "Imported Successfully"),
			   isPresented: $showImportSuccessAlert,
			   actions: { },
		message: {
			Text("alert.message.imported-theme-successfully.\(showImportConfirmationAlert.0?.name ?? "")", comment: "The theme “%@” has been imported.")
		})
		.alert(Text("alert.title.error", comment: "Error"),
			   isPresented: $showImportErrorAlert.1,
			   actions: { }, message: {
			Text(verbatim: "\(showImportErrorAlert.0?.localizedDescription ?? "")")
		})
		.onReceive(themeManager.objectWillChange) { _ in
			updateThemesArrays()
		}
    }
	
	func articleThemeRow(_ theme: ArticleTheme) -> some View {
		Button {
			themeManager.currentThemeName = theme.name
		} label: {
			HStack {
				VStack(alignment: .leading) {
					Text(verbatim: theme.name)
						.foregroundColor(.primary)
					Text("label.text.theme-created-byline.\(theme.creatorName)", comment: "Created by %@")
						.font(.caption)
						.foregroundColor(.secondary)
				}
				Spacer()
				if themeManager.currentThemeName == theme.name {
					Image(systemName: "checkmark")
						.foregroundColor(Color(uiColor: AppAssets.primaryAccentColor))
				}
			}
			
		}
		.swipeActions(edge: .trailing, allowsFullSwipe: false) {
			if theme.isAppTheme || theme.name == themeManager.currentThemeName {
				
			} else {
				Button {
					showDeleteConfirmation = (theme.name, true)
				} label: {
					Text("button.title.delete", comment: "Delete")
					Image(systemName: "trash")
				}
				.tint(.red)
			}
		}
	}
	
	private func updateThemesArrays() {
		installedFirstPartyThemes = themeManager.themeNames.map({ try? themeManager.articleThemeWithThemeName($0) }).compactMap({ $0 }).filter({ $0.isAppTheme }).sorted(by: { $0.name < $1.name })
		
		installedThirdPartyThemes = themeManager.themeNames.map({ try? themeManager.articleThemeWithThemeName($0) }).compactMap({ $0 }).filter({ !$0.isAppTheme }).sorted(by: { $0.name < $1.name })
	}
}

struct ArticleThemeImporterView_Previews: PreviewProvider {
    static var previews: some View {
        ArticleThemeManagerView()
    }
}
