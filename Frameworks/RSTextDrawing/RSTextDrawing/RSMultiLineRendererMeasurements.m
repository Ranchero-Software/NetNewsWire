//
//  RSMultiLineRendererMeasurements.m
//  RSTextDrawing
//
//  Created by Brent Simmons on 3/4/16.
//  Copyright © 2016 Ranchero Software. All rights reserved.
//

#import "RSMultiLineRendererMeasurements.h"

@implementation RSMultiLineRendererMeasurements

#pragma mark - Class Methods

+ (instancetype)measurementsWithHeight:(NSInteger)height heightOfFirstLine:(NSInteger)heightOfFirstLine {
	
	return [[self alloc] initWithHeight:height heightOfFirstLine:heightOfFirstLine];
}


#pragma mark - Init

- (instancetype)initWithHeight:(NSInteger)height heightOfFirstLine:(NSInteger)heightOfFirstLine {
	
	self = [super init];
	if (!self) {
		return nil;
	}
	
	_height = height;
	_heightOfFirstLine = heightOfFirstLine;
	
	return self;
}

- (BOOL)isEqualToMultiLineRendererMeasurements:(RSMultiLineRendererMeasurements *)otherMeasurements {
	
	return self.height == otherMeasurements.height && self.heightOfFirstLine == otherMeasurements.heightOfFirstLine;
}

- (BOOL)isEqual:(id)object {
	
	if (self == object) {
		return YES;
	}
	if (![object isKindOfClass:[self class]]) {
		return NO;
	}
	
	return [self isEqualToMultiLineRendererMeasurements:(RSMultiLineRendererMeasurements *)object];
}

- (NSUInteger)hash {
	
	return (NSUInteger)(self.height + (self.heightOfFirstLine * 100000));
}


@end
