//
//  NSPasteboard+RSCore.m
//  RSCore
//
//  Created by Brent Simmons on 11/14/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

#import "NSPasteboard+RSCore.h"
#import "NSString+RSCore.h"


@implementation NSPasteboard (RSCore)

+ (nullable NSString *)rs_urlStringFromPasteboard:(NSPasteboard *)pasteboard {

	return [pasteboard rs_urlString];
}

- (nullable NSString *)rs_urlString {

	NSString *type = [self availableTypeFromArray:@[NSStringPboardType]];
	if (!type) {
		return nil;
	}

	NSString *s = [self stringForType:type];
	if (RSStringIsEmpty(s)) {
		return nil;
	}

	if ([s rs_stringMayBeURL]) {
		return s;
	}

	return nil;
}

@end
