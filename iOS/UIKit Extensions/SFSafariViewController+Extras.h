//
//  SFSafariViewControllerExtras.h
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 11/29/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

@import SafariServices;

NS_ASSUME_NONNULL_BEGIN

@interface SFSafariViewController (Extras)

+ (nullable SFSafariViewController *)safeSafariViewController:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
