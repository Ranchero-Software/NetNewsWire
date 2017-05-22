//
//  RSMultiLineRendererMeasurements.h
//  RSTextDrawing
//
//  Created by Brent Simmons on 3/4/16.
//  Copyright © 2016 Ranchero Software. All rights reserved.
//

@import Foundation;

@interface RSMultiLineRendererMeasurements : NSObject

+ (instancetype)measurementsWithHeight:(NSInteger)height heightOfFirstLine:(NSInteger)heightOfFirstLine;

@property (nonatomic, readonly) NSInteger height;
@property (nonatomic, readonly) NSInteger heightOfFirstLine;

@end
