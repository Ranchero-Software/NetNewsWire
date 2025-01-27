//
//  AppAsset.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 1/26/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import RSCore
import Account

struct AppAsset {

	// MARK: - Account images

	static func image(accountType: AccountType) -> RSImage? {
		switch accountType {
		case .onMyMac:
			AppAsset.accountLocalImage
		case .cloudKit:
			AppAsset.accountCloudKitImage
		case .feedbin:
			AppAsset.accountFeedbinImage
		case .feedly:
			AppAsset.accountFeedlyImage
		case .freshRSS:
			AppAsset.accountFreshRSSImage
		case .newsBlur:
			AppAsset.accountNewsBlurImage
		case .inoreader:
			AppAsset.accountInoreaderImage
		case .bazQux:
			AppAsset.accountBazQuxImage
		case .theOldReader:
			AppAsset.accountTheOldReaderImage
		}
	}

	// MARK: - Misc.

	static let nnwFeedIcon = RSImage(named: "nnwFeedIcon")!


}

private extension AppAsset {

	static var accountBazQuxImage = RSImage(named: "accountBazQux")!
	static var accountCloudKitImage = RSImage(named: "accountCloudKit")!
	static var accountFeedbinImage = RSImage(named: "accountFeedbin")!
	static var accountFeedlyImage = RSImage(named: "accountFeedly")!
	static var accountFreshRSSImage = RSImage(named: "accountFreshRSS")!
	static var accountInoreaderImage = RSImage(named: "accountInoreader")!
	static var accountNewsBlurImage = RSImage(named: "accountNewsBlur")!
	static var accountTheOldReaderImage = RSImage(named: "accountTheOldReader")!

#if os(macOS)
	static var accountLocalMacImage = RSImage(named: "accountLocal")!
#elseif os(iOS)
	static var accountLocalPadImage = UIImage(named: "accountLocalPad")!
	static var accountLocalPhoneImage = UIImage(named: "accountLocalPhone")!
#endif

	static var accountLocalImage: RSImage = {
#if os(macOS)
		accountLocalMacImage
#elseif os(iOS)
		if UIDevice.current.userInterfaceIdiom == .pad {
			return accountLocalPadImage
		} else {
			return accountLocalPhoneImage
		}
#endif
	}()
}
