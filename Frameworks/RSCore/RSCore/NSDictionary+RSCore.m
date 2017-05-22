//
//  NSDictionary+RSCore.m
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

#import "NSDictionary+RSCore.h"

@implementation NSDictionary (RSCore)


- (id)rs_objectForCaseInsensitiveKey:(NSString *)key {

	id obj = self[key];
	if (obj) {
		return obj;
	}
	
	for (NSString *oneKey in self.allKeys) {
		
		if ([oneKey isKindOfClass:[NSString class]] && [key caseInsensitiveCompare:oneKey] == NSOrderedSame) {
			return self[oneKey];
		}
	}
	
	return nil;
}


- (BOOL)rs_boolForKey:(NSString *)key {

	id obj = self[key];

	if ([obj respondsToSelector:@selector(boolValue)]) {
		return [obj boolValue];
	}

	return NO;
}


- (int64_t)rs_int64ForKey:(NSString *)key {

	id obj = self[key];
	if (!obj) {
		return 0LL;
	}

	if ([obj respondsToSelector:@selector(longLongValue)]) {
		return ((NSNumber *)(obj)).longLongValue;
	}

	return 0LL;
}


@end
