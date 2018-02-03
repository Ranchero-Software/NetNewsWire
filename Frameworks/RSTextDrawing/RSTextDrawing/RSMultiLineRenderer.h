//
//  RSMultiLineRenderer.h
//  RSTextDrawing
//
//  Created by Brent Simmons on 3/3/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import AppKit;
#import <RSTextDrawing/RSTextRendererProtocol.h>

NS_ASSUME_NONNULL_BEGIN

@class RSMultiLineRendererMeasurements;


@interface RSMultiLineRenderer : NSObject <RSTextRenderer>

+ (instancetype)rendererWithAttributedTitle:(NSAttributedString *)title;

- (RSMultiLineRendererMeasurements *)measurementsForWidth:(CGFloat)width;

@property (nonatomic, strong) NSColor *backgroundColor; // Default is white.

@end

NS_ASSUME_NONNULL_END

