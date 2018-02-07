//
//  RSMultiLineView.h
//  RSTextDrawing
//
//  Created by Brent Simmons on 5/27/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import AppKit;

NS_ASSUME_NONNULL_BEGIN

@class RSMultiLineRendererMeasurements;

@interface RSMultiLineView : NSView

@property (nonatomic) NSAttributedString *attributedStringValue;

@property (nonatomic, readonly) RSMultiLineRendererMeasurements *measurements;

@property (nonatomic) BOOL selected;
@property (nonatomic) BOOL emphasized;

@end

NS_ASSUME_NONNULL_END
