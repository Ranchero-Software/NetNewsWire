//
//  NSSet+RSCore.m
//  RSCore
//
//  Created by Brent Simmons on 8/15/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

#import "NSSet+RSCore.h"

@implementation NSSet (RSCore)

- (id)rs_anyObjectPassingTest:(RSTestBlock)testBlock {
	
	for (id oneObject in self) {
		
		if (testBlock(oneObject)) {
			return oneObject;
		}
	}
	
	return nil;
}


- (NSSet *)rs_filter:(RSFilterBlock)filterBlock {
	
	NSMutableSet *filteredSet = [NSMutableSet new];
	
	for (id oneObject in self) {
		
		if (filterBlock(oneObject)) {
			[filteredSet addObject:oneObject];
		}
	}
	
	return [filteredSet copy];
}


- (NSSet *)rs_objectsConformingToProtocol:(Protocol *)p {
	
	return [self rs_filter:^BOOL(id obj) {
		return [obj conformsToProtocol:p];
	}];
}

@end
