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
		return RSImage(named: "AccountLocalMac")
	}()

	static var accountLocalPadImage: RSImage = {
		return RSImage(named: "AccountLocalPad")!
	}()

	static var accountLocalPhoneImage: RSImage = {
		return RSImage(named: "AccountLocalPhone")!
	}()

	static var accountCloudKitImage: RSImage = {
		return RSImage(named: "AccountCloudKit")!
	}()

	static var accountFeedbinImage: RSImage = {
		return RSImage(named: "AccountFeedbin")!
	}()

	static var accountFeedlyImage: RSImage = {
		return RSImage(named: "AccountFeedly")!
	}()
	
	static var accountFeedWranglerImage: RSImage = {
		return RSImage(named: "AccountFeedWrangler")!
	}()

	static var accountFreshRSSImage: RSImage = {
		return RSImage(named: "AccountFreshRSS")!
	}()

	static var accountNewsBlurImage: RSImage = {
		return RSImage(named: "AccountNewsBlur")!
	}()

	static var addMenuImage: Image = {
		return Image(systemName: "plus")
	}()
	
	static var extensionPointMarsEdit: RSImage = {
		return RSImage(named: "ExtensionPointMarsEdit")!
	}()
	
	static var extensionPointMicroblog: RSImage = {
		return RSImage(named: "ExtensionPointMicroblog")!
	}()

	static var extensionPointReddit: RSImage = {
		return RSImage(named: "ExtensionPointReddit")!
	}()

	static var extensionPointTwitter: RSImage = {
		return RSImage(named: "ExtensionPointTwitter")!
	}()
	
	static var faviconTemplateImage: RSImage = {
		return RSImage(named: "FaviconTemplateImage")!
	}()
	
	static var settingsImage: Image = {
		return Image(systemName: "gear")
	}()
	
	static var masterFolderImage: IconImage {
		#if os(macOS)
		let image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)!
		let coloredImage = image.tinted(with: NSColor(named: "AccentColor")!)
		return IconImage(coloredImage)
		#endif
		#if os(iOS)
		let image = UIImage(systemName: "folder.fill")!
		let coloredImage = image.tinted(color: UIColor(named: "AccentColor")!)!
		return IconImage(coloredImage)
		#endif
	}
	
	static var markAllAsReadImage: Image = {
		return Image("MarkAllAsRead")
	}()
	
	static var markAllAsReadImagePDF: Image = {
		return Image("MarkAllAsReadPDF")
	}()
	
	static var nextUnreadArticleImage: Image = {
		return Image(systemName: "chevron.down.circle")
	}()
	
	static var openInBrowserImage: Image = {
		return Image(systemName: "safari")
	}()

	static var refreshImage: Image = {
		return Image(systemName: "arrow.clockwise")
	}()

	static var searchFeedImage: IconImage = {
		#if os(macOS)
		return IconImage(NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)!)
		#endif
		#if os(iOS)
		return IconImage(UIImage(systemName: "magnifyingglass")!)
		#endif
	}()
	
	static var shareImage: Image = {
		Image(systemName: "square.and.arrow.up")
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
		let image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)!
		let coloredImage = image.tinted(with: NSColor(named: "StarColor")!)
		return IconImage(coloredImage)
		#endif
		#if os(iOS)
		let image = UIImage(systemName: "star.fill")!
		let coloredImage = image.tinted(color: UIColor(named: "StarColor")!)!
		return IconImage(coloredImage)
		#endif
	}()
	
	static var timelineStarred: Image = {
		#if os(macOS)
		let image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)!
		let coloredImage = image.tinted(with: NSColor(named: "StarColor")!)
		return Image(nsImage: coloredImage)
		#endif
		#if os(iOS)
		let image = UIImage(systemName: "star.fill")!
		let coloredImage = image.tinted(color: UIColor(named: "StarColor")!)!
		return Image(uiImage: coloredImage)
		#endif
	}()

	static var timelineUnread: Image {
		#if os(macOS)
		let image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)!
		let coloredImage = image.tinted(with: NSColor(named: "AccentColor")!)
		return Image(nsImage: coloredImage)
		#endif
		#if os(iOS)
		let image = UIImage(systemName: "circle.fill")!
		let coloredImage = image.tinted(color: UIColor(named: "AccentColor")!)!
		return Image(uiImage: coloredImage)
		#endif
	}
	
	static var todayFeedImage: IconImage = {
		#if os(macOS)
		let image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: nil)!
		let coloredImage = image.tinted(with: .orange)
		return IconImage(coloredImage)
		#endif
		#if os(iOS)
		let image = UIImage(systemName: "sun.max.fill")!
		let coloredImage = image.tinted(color: .orange)!
		return IconImage(coloredImage)
		#endif
	}()

	static var toggleStarred: Image = {
		return Image(systemName: "star.fill")
	}()

	static var toggleRead: Image = {
		return Image(systemName: "largecircle.fill.circle")
	}()

	static var unreadFeedImage: IconImage {
		#if os(macOS)
		let image = NSImage(systemSymbolName: "largecircle.fill.circle", accessibilityDescription: nil)!
		let coloredImage = image.tinted(with: NSColor(named: "AccentColor")!)
		return IconImage(coloredImage)
		#endif
		#if os(iOS)
		let image = UIImage(systemName: "largecircle.fill.circle")!
		let coloredImage = image.tinted(color: UIColor(named: "AccentColor")!)!
		return IconImage(coloredImage)
		#endif
	}

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
