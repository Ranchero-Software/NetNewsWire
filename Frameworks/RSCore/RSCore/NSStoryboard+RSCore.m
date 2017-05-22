//
//  NSStoryboard+RSCore.m
//  RSCore
//
//  Created by Brent Simmons on 11/20/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

#import "NSStoryboard+RSCore.h"

@implementation NSStoryboard (RSCore)

+ (id)rs_initialControllerWithStoryboardName:(NSString *)storyboardName {
	
	NSStoryboard *storyboard = [self storyboardWithName:storyboardName bundle:nil];
	return [storyboard instantiateInitialController];
}

@end
