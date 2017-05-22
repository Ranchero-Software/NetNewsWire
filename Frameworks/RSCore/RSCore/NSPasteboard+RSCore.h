//
//  NSPasteboard+RSCore.h
//  RSCore
//
//  Created by Brent Simmons on 11/14/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

@import AppKit;

NS_ASSUME_NONNULL_BEGIN

@interface NSPasteboard (RSCore)

/*Pulls something that looks like a URL from the pasteboard. May return nil.
 The string won’t be normalized — for instance, it could return "apple.com".
 And the string may not really be a URL.*/

+ (nullable NSString *)rs_urlStringFromPasteboard:(NSPasteboard *)pasteboard;

@end

NS_ASSUME_NONNULL_END
