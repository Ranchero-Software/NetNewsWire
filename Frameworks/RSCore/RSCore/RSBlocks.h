//
//  RSBlocks.h
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software LLC. All rights reserved.
//

@import Foundation;
#import <RSCore/RSPlatform.h>

#if TARGET_OS_IPHONE
@import UIKit;
#endif

typedef void (^RSVoidBlock)(void);

typedef RSVoidBlock RSVoidCompletionBlock;

typedef BOOL (^RSBoolBlock)(void);

typedef void (^RSFetchResultsBlock)(NSArray *fetchedObjects);

typedef void (^RSDataResultBlock)(NSData *d);

typedef void (^RSObjectResultBlock)(id obj);

typedef void (^RSSetResultBlock)(NSSet *set);

typedef void (^RSBoolResultBlock)(BOOL flag);

typedef BOOL (^RSTestBlock)(id obj);

/*Images*/

typedef void (^RSImageResultBlock)(RS_IMAGE *image);

typedef RS_IMAGE *(^RSImageRenderBlock)(RS_IMAGE *imageToRender);


/*Calls on main thread. Ignores if nil.*/

void RSCallCompletionBlock(RSVoidCompletionBlock completion);

void RSCallBlockWithParameter(RSObjectResultBlock block, id obj);

