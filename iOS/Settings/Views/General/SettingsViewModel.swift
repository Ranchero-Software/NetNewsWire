//
//  SettingsViewModel.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 29/11/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import UniformTypeIdentifiers
import UserNotifications


public final class SettingsViewModel: ObservableObject {
	
	@Published public var showAddAccountView: Bool = false
	@Published public var helpSheet: HelpSheet = .help
	@Published public var showHelpSheet: Bool = false
	@Published public var showAbout: Bool = false
	@Published public var notificationPermissions: UNAuthorizationStatus = .notDetermined
	@Published public var importAccount: Account? = nil
	@Published public var exportAccount: Account? = nil
	@Published public var showImportView: Bool = false
	@Published public var showExportView: Bool = false
	@Published public var showImportExportError: Bool = false
	@Published public var importExportError: Error?
	@Published public var showImportSuccess: Bool = false
	@Published public var showExportSuccess: Bool = false
	@Published public var exportDocument: OPMLDocument?

}
