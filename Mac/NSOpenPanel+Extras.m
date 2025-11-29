//
//  NSOpenPanel+Extras.m
//  NetNewsWire
//
//  Created by Brent Simmons on 11/29/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

#import "NSOpenPanel+Extras.h"

// https://github.com/Ranchero-Software/NetNewsWire/issues/4840
//
// We use the deprecated `allowedFileTypes` because using `allowedContentTypes`
// is unreliable — we can’t guarantee that the UTI for OPML on a given
// computer is what we expect it to be. So we just specify the file extension.
// We suppress the deprecation warning because we know we’re doing this
// on purpose.

@implementation NSOpenPanel (NoDeprecationWarning)

- (void)acceptOPML {

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

	self.allowedFileTypes = @[@"opml", @"xml"];

#pragma clang diagnostic pop
}

@end
