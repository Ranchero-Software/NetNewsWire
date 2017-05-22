//
//  RSImageRenderer.h
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;
#import "RSBlocks.h"


/*Used to render an image based on another image. (Thumbnails, for instance.)
 Thread-safe. Renders in a background queue.

 imageRenderBlock is responsible for dealing with graphics context; it returns the rendered image.

 imageResultBlock may be called on any thread.

 None of the parameters may be nil.
 */


@interface RSImageRenderer : NSObject


- (instancetype)initWithRenderer:(RSImageRenderBlock)imageRenderBlock;

- (void)renderImage:(RS_IMAGE *)originalImage imageResultBlock:(RSImageResultBlock)imageResultBlock;


@end
