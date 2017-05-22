//
//  NSArray+RSCore.m
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

#import "NSArray+RSCore.h"


BOOL RSEqualArrays(NSArray *array1, NSArray *array2) {

	return array1 == array2 || [array1 isEqualToArray:array2];
}


@implementation NSArray (RSCore)


- (id)rs_safeObjectAtIndex:(NSUInteger)ix {

	if (self.count < 1 || ix >= self.count) {
		return nil;
	}

	return self[ix];
}


- (id)rs_firstObjectWhereValueForKey:(NSString *)key equalsValue:(id)value {

	return [self rs_firstObjectPassingTest:^BOOL(id obj) {
		return [[obj valueForKey:key] isEqual:value];
	}];
}


- (id)rs_firstObjectPassingTest:(RSTestBlock)testBlock {
	
	for (id oneObject in self) {
		if (testBlock(oneObject)) {
			return oneObject;
		}
	}
	return nil;
}


- (NSArray *)rs_map:(RSMapBlock)mapBlock {

	NSMutableArray *mappedArray = [NSMutableArray new];

	for (id oneObject in self) {

		id objectToAdd = mapBlock(oneObject);
		if (objectToAdd) {
			[mappedArray addObject:objectToAdd];
		}
	}

	return [mappedArray copy];
}


- (NSArray *)rs_filter:(RSFilterBlock)filterBlock {
	
	NSMutableArray *filteredArray = [NSMutableArray new];
	
	for (id oneObject in self) {
		
		if (filterBlock(oneObject)) {
			[filteredArray addObject:oneObject];
		}
	}
	
	return [filteredArray copy];
}


- (NSArray *)rs_arrayWithCopyOfEachObject {

	return [self rs_map:^id(id obj) {
		return [obj copy];
	}];
}


- (NSDictionary *)rs_dictionaryUsingKey:(id)key {

	NSMutableDictionary *d = [NSMutableDictionary new];

	for (id oneObject in self) {

		id oneUniqueID = [oneObject valueForKey:key];
		d[oneUniqueID] = oneObject;
	}

	return [d copy];
}


@end
