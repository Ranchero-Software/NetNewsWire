//
//  NSMutableDictionary+RSCore.m
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

#import "NSMutableDictionary+RSCore.h"


@implementation NSMutableDictionary (RSCore)


- (void)rs_safeSetObject:(id)obj forKey:(id)key {
	if (obj != nil & key != nil) {
		[self setObject:obj forKey:key];
	}
}


- (void)rs_removeObjectsForKeys:(NSArray *)keys {

	for (id oneKey in keys) {
		[self removeObjectForKey:oneKey];
	}
}
@end
