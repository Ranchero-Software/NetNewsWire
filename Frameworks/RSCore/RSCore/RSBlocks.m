//
//  RSBlocks.m
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software LLC. All rights reserved.
//

#import "RSBlocks.h"

void RSCallCompletionBlock(RSVoidCompletionBlock completion) {

	if (!completion) {
		return;
	}

	dispatch_async(dispatch_get_main_queue(), ^{
		@autoreleasepool {
			completion();
		}
	});
}

void RSCallBlockWithParameter(RSObjectResultBlock block, id obj) {

	if (!block) {
		return;
	}

	dispatch_async(dispatch_get_main_queue(), ^{
		@autoreleasepool {
			block(obj);
		}
	});
}

