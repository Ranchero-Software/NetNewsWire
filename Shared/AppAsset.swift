//
//  AppAsset.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/7/24.
//  Copyright © 2024 Ranchero Software. All rights reserved.
//

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

import Core
import Account

final class AppAsset {

	struct Account {

		static let bazQux = RSImage.appImage("accountBazQux")
		static let cloudKit = RSImage.appImage("accountCloudKit")
		static let feedbin = RSImage.appImage("accountFeedbin")
		static let feedly = RSImage.appImage("accountFeedly")
		static let freshRSS = RSImage.appImage("accountFreshRSS")
		static let inoReader = RSImage.appImage("accountInoreader")
		static let local = RSImage.appImage("accountLocal")
		static let localPad = RSImage.appImage("accountLocalPad")
		static let localPhone = RSImage.appImage("accountLocalPhone")
		static let newsBlur = RSImage.appImage("accountNewsBlur")
		static let theOldReader = RSImage.appImage("accountTheOldReader")

		@MainActor static func image(for accountType: AccountType) -> RSImage {

			switch accountType {
			case .onMyMac:

				#if os(macOS)
				return AppAsset.Account.local

				#elseif os(iOS)
				if UIDevice.current.userInterfaceIdiom == .pad {
					return AppAsset.Account.localPad
				} else {
					return AppAsset.Account.localPhone
				}
				
				#endif

			case .cloudKit:
				return AppAsset.Account.cloudKit
			case .bazQux:
				return AppAsset.Account.bazQux
			case .feedbin:
				return AppAsset.Account.feedbin
			case .feedly:
				return AppAsset.Account.feedly
			case .freshRSS:
				return AppAsset.Account.freshRSS
			case .inoreader:
				return AppAsset.Account.inoReader
			case .newsBlur:
				return AppAsset.Account.newsBlur
			case .theOldReader:
				return AppAsset.Account.theOldReader
			}
		}
	}

	struct ArticleExtractor {

		static let error = RSImage.appImage("articleExtractorError")
		static let off = RSImage.appImage("articleExtractorOff")
		static let offSF = RSImage.systemImage("doc.plaintext")
		static let on = RSImage.appImage("articleExtractorOn")
		static let onSF = RSImage.appImage("articleExtractorOnSF")
	}
}
