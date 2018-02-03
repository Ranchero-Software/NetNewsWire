//
//  RSTransparentContainerView.h
//  RSCore
//
//  Created by Brent Simmons on 9/19/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import AppKit;

/*This view has one subview, which it resizes to fit the bounds of this view.*/

@interface RSTransparentContainerView : NSView

@property (nonatomic) NSView *containedView; /*Removes old.*/

@end
