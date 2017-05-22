//
//  NSImage+RSCore.m
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

#import "NSImage+RSCore.h"


@implementation NSImage (RSCore)


+ (void)rs_imageWithData:(NSData *)data imageResultBlock:(RSImageResultBlock)imageResultBlock {

	NSParameterAssert(data != nil);

	NSImage *image = [[NSImage alloc] initWithData:data];

	RSCallBlockWithParameter(imageResultBlock, image);
}


+ (instancetype)imageWithContentsOfFile:(NSString *)f {

	return [[self alloc] initWithContentsOfFile:f];
}


@end
