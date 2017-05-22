//
//  RSImageRenderer.m
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

#import "RSImageRenderer.h"

static void RSImageRender(RS_IMAGE *originalImage, RSImageRenderBlock renderer, RSImageResultBlock imageCallback) {

	assert(originalImage != nil);
	assert(renderer != nil);
	assert(imageCallback != nil);

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{

		@autoreleasepool {

			RS_IMAGE *renderedImage = renderer(originalImage);
			imageCallback(renderedImage);
		}
	});
}



@interface RSImageRenderer ()

@property (nonatomic, copy) RSImageRenderBlock imageRenderBlock;

@end



@implementation RSImageRenderer


#pragma mark - Init

- (instancetype)initWithRenderer:(RSImageRenderBlock)imageRenderBlock {

	NSParameterAssert(imageRenderBlock != nil);

	self = [super init];
	if (self == nil) {
		return nil;
	}

	_imageRenderBlock = imageRenderBlock;

	return self;
}


#pragma mark - API

- (void)renderImage:(RS_IMAGE *)originalImage imageResultBlock:(RSImageResultBlock)imageResultBlock {

	NSParameterAssert(originalImage != nil);
	NSParameterAssert(imageResultBlock != nil);

	RSImageRender(originalImage, self.imageRenderBlock, imageResultBlock);
}


@end

