//
//  OAuthAuthorizationClient+Feedly.swift
//  Account
//
//  Created by Kiel Gillard on 8/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import Secrets

nonisolated extension OAuthAuthorizationClient {

	static var feedlyCloudClient: OAuthAuthorizationClient {
		/// Models private NetNewsWire client secrets.
		/// These placeholders are substituted at build time using a Run Script phase with build settings.
		/// https://developer.feedly.com/v3/auth/#authenticating-a-user-and-obtaining-an-auth-code
		return OAuthAuthorizationClient(id: SecretKey.feedlyClientID,
										redirectURI: "netnewswire://auth/feedly",
										secret: SecretKey.feedlyClientSecret)
	}
}
