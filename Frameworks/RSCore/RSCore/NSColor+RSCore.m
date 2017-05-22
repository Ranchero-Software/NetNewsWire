//
//  NSColor+RSCore.m
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

#import "NSColor+RSCore.h"
#import "NSString+RSCore.h"


@implementation NSColor (RSCore)


+ (NSColor *)rs_colorWithHexString:(NSString *)hexString {

	RSRGBAComponents components = [hexString rs_rgbaComponents];

	return [NSColor colorWithRed:components.red green:components.green blue:components.blue alpha:components.alpha];
}


@end
