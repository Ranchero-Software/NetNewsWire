//
//  SingleLineRenderer.h
//  RSTextDrawing
//
//  Created by Brent Simmons on 3/3/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import AppKit;
#import <RSTextDrawing/RSTextRendererProtocol.h>

NS_ASSUME_NONNULL_BEGIN

@interface RSSingleLineRenderer : NSObject <RSTextRenderer>

+ (instancetype)rendererWithAttributedTitle:(NSAttributedString *)title;

@property (nonatomic, readonly) NSSize size;

@property (nonatomic, strong) NSColor *backgroundColor; // Default is white.

@end

NS_ASSUME_NONNULL_END
