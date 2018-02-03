//
//  RSTextRendererProtocol.h
//  RSTextDrawing
//
//  Created by Brent Simmons on 3/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import AppKit;

@protocol RSTextRenderer <NSObject>

- (void)renderTextInRect:(NSRect)r;

+ (void)emptyCache;

@end
