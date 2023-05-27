//
//  AccountSectionHeader.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 18/12/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct AccountSectionHeader: View {
    
	var accountType: AccountType

	var body: some View {
		Section(header: headerImage) {}
    }
	
	var headerImage: some View {
		HStack {
			Spacer()
			Image(uiImage: imageToUse())
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(width: 48, height: 48)
			Spacer()
		}
	}
	
	private func imageToUse() -> UIImage {
		switch accountType {
		case .onMyMac:
			if UIDevice.current.userInterfaceIdiom == .pad { return AppAssets.accountLocalPadImage }
			return AppAssets.accountLocalPhoneImage
		case .cloudKit:
			return AppAssets.accountCloudKitImage
		case .feedly:
			return AppAssets.accountFeedlyImage
		case .feedbin:
			return AppAssets.accountFeedbinImage
		case .newsBlur:
			return AppAssets.accountNewsBlurImage
		case .freshRSS:
			return AppAssets.accountFreshRSSImage
		case .inoreader:
			return AppAssets.accountInoreaderImage
		case .bazQux:
			return AppAssets.accountBazQuxImage
		case .theOldReader:
			return AppAssets.accountTheOldReaderImage
		}
	}
	
}

struct AccountHeader_Previews: PreviewProvider {
    static var previews: some View {
		AccountSectionHeader(accountType: .onMyMac)
    }
}
