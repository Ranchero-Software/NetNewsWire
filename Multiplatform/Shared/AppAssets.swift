//
//  AppAssets.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/27/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import RSCore
import Account

struct AppAssets {
	
	static var accountLocalMacImage: RSImage! = {
		return RSImage(named: "accountLocalMac")
	}()

	static var accountLocalPadImage: RSImage = {
		return RSImage(named: "accountLocalPad")!
	}()

	static var accountLocalPhoneImage: RSImage = {
		return RSImage(named: "accountLocalPhone")!
	}()

	static var accountCloudKitImage: RSImage = {
		return RSImage(named: "accountCloudKit")!
	}()

	static var accountFeedbinImage: RSImage = {
		return RSImage(named: "accountFeedbin")!
	}()

	static var accountFeedlyImage: RSImage = {
		return RSImage(named: "accountFeedly")!
	}()
	
	static var accountFeedWranglerImage: RSImage = {
		return RSImage(named: "accountFeedWrangler")!
	}()

	static var accountFreshRSSImage: RSImage = {
		return RSImage(named: "accountFreshRSS")!
	}()

	static var accountNewsBlurImage: RSImage = {
		return RSImage(named: "accountNewsBlur")!
	}()

	static var extensionPointMarsEdit: RSImage = {
		return RSImage(named: "extensionPointMarsEdit")!
	}()
	
	static var extensionPointMicroblog: RSImage = {
		return RSImage(named: "extensionPointMicroblog")!
	}()

	static var extensionPointReddit: RSImage = {
		return RSImage(named: "extensionPointReddit")!
	}()

	static var extensionPointTwitter: RSImage = {
		return RSImage(named: "extensionPointTwitter")!
	}()
	
	static var faviconTemplateImage: RSImage = {
		return RSImage(named: "faviconTemplateImage")!
	}()
	
	static var masterFolderImage: IconImage = {
		#if os(macOS)
		return IconImage(NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)!)
		#endif
		#if os(iOS)
		return IconImage(UIImage(systemName: "folder.fill")!)
		#endif
	}()
	
	static var searchFeedImage: IconImage = {
		#if os(macOS)
		return IconImage(NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)!)
		#endif
		#if os(iOS)
		return IconImage(UIImage(systemName: "magnifyingglass")!)
		#endif
	}()
	
	static var smartFeedImage: RSImage = {
		#if os(macOS)
		return NSImage(systemSymbolName: "gear", accessibilityDescription: nil)!
		#endif
		#if os(iOS)
		return UIImage(systemName: "gear")!
		#endif
	}()
	
	static var starredFeedImage: IconImage = {
		#if os(macOS)
		return IconImage(NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)!)
		#endif
		#if os(iOS)
		return IconImage(UIImage(systemName: "star.fill")!)
		#endif
	}()
	
	static var todayFeedImage: IconImage = {
		#if os(macOS)
		return IconImage(NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: nil)!)
		#endif
		#if os(iOS)
		return IconImage(UIImage(systemName: "sun.max.fill")!)
		#endif
	}()
	
	static var unreadFeedImage: IconImage = {
		#if os(macOS)
		return IconImage(NSImage(systemSymbolName: "largecircle.fill.circle", accessibilityDescription: nil)!)
		#endif
		#if os(iOS)
		return IconImage(UIImage(systemName: "largecircle.fill.circle")!)
		#endif
	}()

	static func image(for accountType: AccountType) -> RSImage? {
		switch accountType {
		case .onMyMac:
			#if os(macOS)
			return AppAssets.accountLocalMacImage
			#endif
			#if os(iOS)
			if UIDevice.current.userInterfaceIdiom == .pad {
				return AppAssets.accountLocalPadImage
			} else {
				return AppAssets.accountLocalPhoneImage
			}
			#endif
		case .cloudKit:
			return AppAssets.accountCloudKitImage
		case .feedbin:
			return AppAssets.accountFeedbinImage
		case .feedly:
			return AppAssets.accountFeedlyImage
		case .feedWrangler:
			return AppAssets.accountFeedWranglerImage
		case .freshRSS:
			return AppAssets.accountFreshRSSImage
		case .newsBlur:
			return AppAssets.accountNewsBlurImage
		}
	}
	
}
