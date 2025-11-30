//
//  SFSafariViewController+Extras.m
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 11/29/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

#import "SFSafariViewController+Extras.h"

@implementation SFSafariViewController (Extras)

/// Safely create an SFSafariViewController.
///
/// Returns nil if it can’t be created due to an exception.
///
/// Reason: <https://github.com/Ranchero-Software/NetNewsWire/issues/4857>
+ (nullable SFSafariViewController *)safeSafariViewController:(NSURL *)url {

	@try {
		return [[SFSafariViewController alloc] initWithURL:url];
	}
	@catch (NSException *exception) {
		NSLog(@"Failed to create SFSafariViewController: %@", exception);
		return nil;
	}
}

@end
