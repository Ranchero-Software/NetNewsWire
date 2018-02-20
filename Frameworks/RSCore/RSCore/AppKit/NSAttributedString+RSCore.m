//
//  NSAttributedString.m
//  RSCore
//
//  Created by Brent Simmons on 2/19/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

#import "NSAttributedString+RSCore.h"

@implementation NSAttributedString (RSCore)

- (NSAttributedString *)rs_attributedStringByMakingTextWhite {

	NSMutableAttributedString *mutableString = [self mutableCopy];
	[mutableString addAttribute:NSForegroundColorAttributeName value:NSColor.whiteColor range:NSMakeRange(0, mutableString.string.length)];
	return [mutableString copy];
}

@end
