//
//  NSStoryboard+RSCore.h
//  RSCore
//
//  Created by Brent Simmons on 11/20/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

@import AppKit;

@interface NSStoryboard (RSCore)

+ (id)rs_initialControllerWithStoryboardName:(NSString *)storyboardName;

@end
