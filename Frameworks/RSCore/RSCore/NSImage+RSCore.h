//
//  NSImage+RSCore.h
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

@import AppKit;
#import "RSBlocks.h"


@interface NSImage (RSCore)


/*Calls -initWithData in background queue. data and imageResultBlock must be non-nil.*/

+ (void)rs_imageWithData:(NSData *)data imageResultBlock:(RSImageResultBlock)imageResultBlock;

+ (instancetype)imageWithContentsOfFile:(NSString *)f;


@end
