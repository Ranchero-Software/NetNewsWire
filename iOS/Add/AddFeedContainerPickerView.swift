//
//  AddFeedContainerPickerView.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 9/18/26.
//

import SwiftUI
import RSCore
import Account

/// List of accounts and their folders, pushed from Add Feed. Choosing one also makes it the default for next time.
struct AddFeedContainerPickerView: View {

	@Binding var selectedContainer: Container?

	@Environment(\.dismiss) private var dismiss

	private let rows: [Row]

	private static let folderIndent: CGFloat = 30
	private static let checkmarkSymbolName = "checkmark"

	private struct Row: Identifiable {
		let container: Container

		var id: ObjectIdentifier {
			ObjectIdentifier(container)
		}
	}

	init(selectedContainer: Binding<Container?>) {
		self._selectedContainer = selectedContainer

		var rows = [Row]()
		for account in AccountManager.shared.sortedActiveAccounts {
			rows.append(Row(container: account))
			for folder in account.sortedFolders ?? [] {
				rows.append(Row(container: folder))
			}
		}
		self.rows = rows
	}

	var body: some View {
		List(rows) { row in
			Button {
				select(row.container)
			} label: {
				HStack {
					if let icon = (row.container as? SmallIconProvider)?.smallIcon {
						IconImageView(icon: icon)
					}
					Text(verbatim: (row.container as? DisplayNameProvider)?.nameForDisplay ?? "")
					Spacer()
					if isSelected(row.container) {
						Image(systemName: Self.checkmarkSymbolName)
							.foregroundStyle(.tint)
					}
				}
				.padding(.leading, row.container is Folder ? Self.folderIndent : 0)
			}
			.foregroundStyle(.primary)
			.disabled(!canSelect(row.container))
		}
		.navigationTitle(NSLocalizedString("Choose Folder", comment: "Choose Folder"))
		.navigationBarTitleDisplayMode(.inline)
	}

	private func isSelected(_ container: Container) -> Bool {
		selectedContainer === container
	}

	/// Some accounts don’t allow feeds at the top level, so those rows are disabled.
	private func canSelect(_ container: Container) -> Bool {
		guard let account = container as? Account else {
			return true
		}
		return !account.behaviors.contains(.disallowFeedInRootFolder)
	}

	private func select(_ container: Container) {
		selectedContainer = container
		AddFeedDefaultContainer.saveDefaultContainer(container)
		dismiss()
	}
}
