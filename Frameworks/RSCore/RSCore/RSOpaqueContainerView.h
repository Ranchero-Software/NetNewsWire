//
//  RSOpaqueContainerView.h
//  RSCore
//
//  Created by Brent Simmons on 3/27/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

@import AppKit;
#import <RSCore/RSBackgroundColorView.h>


/*This view has one subview, which it resizes to fit the bounds of this view.*/

@interface RSOpaqueContainerView : RSBackgroundColorView


@property (nonatomic) NSView *containedView; /*Removes old.*/


@end
