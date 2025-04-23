//
//  FMResultSet+RSExtras.h
//  RSDatabase
//
//  Created by Brent Simmons on 2/19/13.
//  Copyright (c) 2013 Ranchero Software, LLC. All rights reserved.
//


#import "FMResultSet.h"

NS_ASSUME_NONNULL_BEGIN

@interface FMResultSet (RSExtras)


- (NSArray *)rs_arrayForSingleColumnResultSet; // Doesn't handle dates.

- (NSSet *)rs_setForSingleColumnResultSet;

@end

NS_ASSUME_NONNULL_END
