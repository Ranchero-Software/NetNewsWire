//
//  RSSingleLineView.h
//  RSTextDrawing
//
//  Created by Brent Simmons on 5/27/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import AppKit;

NS_ASSUME_NONNULL_BEGIN

@interface RSSingleLineView : NSView

@property (nonatomic, strong) NSAttributedString *attributedStringValue;

@property (nonatomic) BOOL selected;
@property (nonatomic) BOOL emphasized;

@end

NS_ASSUME_NONNULL_END
