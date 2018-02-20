//
//  NSAttributedString.h
//  RSCore
//
//  Created by Brent Simmons on 2/19/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

@import AppKit;

@interface NSAttributedString (RSCore)

// Useful for table/outline views when a row is selected.

- (NSAttributedString *)rs_attributedStringByMakingTextWhite;

@end
