//
//  NSSet+RSCore.h
//  RSCore
//
//  Created by Brent Simmons on 8/15/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;
#import <RSCore/RSBlocks.h>
#import <RSCore/NSArray+RSCore.h>


@interface NSSet (RSCore)

- (id)rs_anyObjectPassingTest:(RSTestBlock)testBlock;

- (NSSet *)rs_filter:(RSFilterBlock)filterBlock;

- (NSSet *)rs_objectsConformingToProtocol:(Protocol *)p;


@end
