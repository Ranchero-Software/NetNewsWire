//
//  FMResultSet+RSExtras.m
//  RSDatabase
//
//  Created by Brent Simmons on 2/19/13.
//  Copyright (c) 2013 Ranchero Software, LLC. All rights reserved.
//

#import "FMResultSet+RSExtras.h"


@implementation FMResultSet (RSExtras)


- (id)valueForKey:(NSString *)key {

	if ([key containsString:@"Date"] || [key containsString:@"date"]) {
		return [self dateForColumn:key];
	}
	
    return [self objectForColumnName:key];
}


- (NSArray *)rs_arrayForSingleColumnResultSet {

	NSMutableArray *results = [NSMutableArray new];

	while ([self next]) {
		id oneObject = [self objectForColumnIndex:0];
		[results addObject:oneObject];
	}

	return [results copy];
}


- (NSSet *)rs_setForSingleColumnResultSet {
	
	NSMutableSet *results = [NSMutableSet new];
	
	while ([self next]) {
		id oneObject = [self objectForColumnIndex:0];
		[results addObject:oneObject];
	}
	
	return [results copy];
}


@end
