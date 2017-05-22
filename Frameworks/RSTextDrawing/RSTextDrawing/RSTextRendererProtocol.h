//
//  RSTextRendererProtocol.h
//  RSTextDrawing
//
//  Created by Brent Simmons on 3/6/16.
//  Copyright © 2016 Ranchero Software. All rights reserved.
//

@import Cocoa;

@protocol RSTextRenderer <NSObject>

- (void)renderTextInRect:(NSRect)r;

+ (void)emptyCache;

@end