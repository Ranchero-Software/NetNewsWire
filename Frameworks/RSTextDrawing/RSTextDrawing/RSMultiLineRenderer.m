//
//  RSMultiLineRenderer.m
//  RSTextDrawing
//
//  Created by Brent Simmons on 3/3/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#import "RSMultiLineRenderer.h"
#import "RSMultiLineRendererMeasurements.h"


@interface RSMultiLineRenderer ()

@property (nonatomic, readonly) NSAttributedString *title;
@property (nonatomic) NSRect rect;
@property (nonatomic, readonly) CTFramesetterRef framesetter;
@property (nonatomic) CTFrameRef frameref;
@property (nonatomic, readonly) NSMutableDictionary *measurementCache;

@end


static NSMutableDictionary *rendererCache = nil;
static NSUInteger kMaximumNumberOfLines = 2;


@implementation RSMultiLineRenderer


#pragma mark - Class Methods

+ (instancetype)rendererWithAttributedTitle:(NSAttributedString *)title {
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		rendererCache = [NSMutableDictionary new];
	});
	
	RSMultiLineRenderer *cachedRenderer = rendererCache[title];
	if (cachedRenderer != nil) {
		return cachedRenderer;
	}
	
	RSMultiLineRenderer *renderer = [[RSMultiLineRenderer alloc] initWithAttributedTitle:title];
	rendererCache[title] = renderer;
	return renderer;
}


+ (void)emptyCache {
	
	for (RSMultiLineRenderer *oneRenderer in rendererCache.allValues) {
		[oneRenderer emptyCache];
		[oneRenderer releaseFrameref];
	}
	
	rendererCache = [NSMutableDictionary new];
}


#pragma mark Init

- (instancetype)initWithAttributedTitle:(NSAttributedString *)title {
	
	self = [super init];
	if (self == nil) {
		return nil;
	}
	
	_title = title;
	_measurementCache = [NSMutableDictionary new];
	_framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)title);
	_backgroundColor = NSColor.whiteColor;
	
	return self;
}


#pragma mark Dealloc

- (void)dealloc {
	
	if (_framesetter) {
		CFRelease(_framesetter);
		_framesetter = nil;
	}
	
	if (_frameref) {
		CFRelease(_frameref);
		_frameref = nil;
	}
}


#pragma mark Accessors

- (void)setRect:(NSRect)r {
	
	r.origin.y = floor(r.origin.y);
	r.origin.x = floor(r.origin.x);
	r.size.height = floor(r.size.height);
	r.size.width = floor(r.size.width);
	
	if (!NSEqualRects(r, _rect)) {
		_rect = r;
		[self releaseFrameref];
	}
}

- (void)releaseFrameref {
	
	if (_frameref) {
		CFRelease(_frameref);
		_frameref = nil;
	}
}

#pragma mark - Measurements

- (NSInteger)integerForWidth:(CGFloat)width {
	
	return (NSInteger)(floor(width));
}


- (NSNumber *)keyForWidth:(CGFloat)width {
	
	return @([self integerForWidth:width]);
}

- (RSMultiLineRendererMeasurements *)measurementsByRegardingNarrowerNeighborsInCache:(CGFloat)width {
	
	/*If width==30, and cached measurements for width==15 indicate that it's a single line of text, then return those measurements.*/
	
	NSInteger w = [self integerForWidth:width];
	static const NSInteger kSingleLineHeightWithSlop = 20;
	
	for (NSNumber *oneKey in self.measurementCache.allKeys) {
		
		NSInteger oneWidth = oneKey.integerValue;
		
		if (oneWidth < w) {
			RSMultiLineRendererMeasurements *oneMeasurements = self.measurementCache[oneKey];
			if (oneMeasurements.height <= kSingleLineHeightWithSlop) {
				return oneMeasurements;
			}
		}
	}
	
	return nil;
}


- (RSMultiLineRendererMeasurements *)measurementsByRegardingNeighborsInCache:(CGFloat)width {
	
	/*If width==30, and the cached measurements for width==15 and width==42 are equal, then we can use one of those for width==30.*/
	
	if (self.measurementCache.count < 2) {
		return nil;
	}
	
	NSInteger w = [self integerForWidth:width];
	NSInteger lessThanNeighbor = NSNotFound;
	NSInteger greaterThanNeighbor = NSNotFound;
	
	for (NSNumber *oneKey in self.measurementCache.allKeys) {
		
		NSInteger oneWidth = oneKey.integerValue;
		if (oneWidth < w) {
			if (lessThanNeighbor == NSNotFound) {
				lessThanNeighbor = oneWidth;
			}
			else if (lessThanNeighbor < oneWidth) {
				lessThanNeighbor = oneWidth;
			}
		}
		if (oneWidth > w) {
			if (greaterThanNeighbor == NSNotFound) {
				greaterThanNeighbor = oneWidth;
			}
			else if (greaterThanNeighbor > oneWidth) {
				greaterThanNeighbor = oneWidth;
			}
		}
	}
	
	if (lessThanNeighbor == NSNotFound || greaterThanNeighbor == NSNotFound) {
		return nil;
	}
	
	RSMultiLineRendererMeasurements *lessThanMeasurements = self.measurementCache[@(lessThanNeighbor)];
	RSMultiLineRendererMeasurements *greaterThanMeasurements = self.measurementCache[@(greaterThanNeighbor)];
	
	if ([lessThanMeasurements isEqual:greaterThanMeasurements]) {
		return lessThanMeasurements;
	}
	
	return nil;
}

- (RSMultiLineRendererMeasurements *)measurementsForWidth:(CGFloat)width {
	
	NSNumber *key = [self keyForWidth:width];
	RSMultiLineRendererMeasurements *cachedMeasurements = self.measurementCache[key];
	if (cachedMeasurements) {
		return cachedMeasurements;
	}
	
	RSMultiLineRendererMeasurements *measurements = [self measurementsByRegardingNarrowerNeighborsInCache:width];
	if (measurements) {
		return measurements;
	}
	measurements = [self measurementsByRegardingNeighborsInCache:width];
	if (measurements) {
		return measurements;
	}
	
	measurements = [self calculatedMeasurementsForWidth:width];
	self.measurementCache[key] = measurements;
	return measurements;
}


#pragma mark - Cache

- (void)emptyCache {
	
	[self.measurementCache removeAllObjects];
}


#pragma mark Rendering

static const CGFloat kMaxHeight = 10000.0;

- (RSMultiLineRendererMeasurements *)calculatedMeasurementsForWidth:(CGFloat)width {
	
	NSInteger height = 0;
	NSInteger heightOfFirstLine = 0;
	
	width = floor(width);
	
	@autoreleasepool {
		
		CGRect r = CGRectMake(0.0f, 0.0f, width, kMaxHeight);
		CGPathRef path = CGPathCreateWithRect(r, NULL);
		
		CTFrameRef frameref = CTFramesetterCreateFrame(self.framesetter, CFRangeMake(0, (CFIndex)(self.title.length)), path, NULL);
		
		NSArray *lines = (__bridge NSArray *)CTFrameGetLines(frameref);
		
		if (lines.count > 0) {
			
			NSUInteger indexOfLastLine = MIN(kMaximumNumberOfLines - 1, lines.count - 1);
			
			CGPoint origins[indexOfLastLine + 1];
			CTFrameGetLineOrigins(frameref, CFRangeMake(0, (CFIndex)indexOfLastLine + 1), origins);
			
			CTLineRef lastLine = (__bridge CTLineRef)lines[indexOfLastLine];
			CGPoint lastOrigin = origins[indexOfLastLine];
			CGFloat descent;
			CTLineGetTypographicBounds(lastLine, NULL, &descent, NULL);
			height = r.size.height - (ceil(lastOrigin.y) - ceil(descent));
			height = (NSInteger)ceil(height);
			
			CTLineRef firstLine = (__bridge CTLineRef)lines[0];
			CGRect firstLineRect = CTLineGetBoundsWithOptions(firstLine, 0);
			heightOfFirstLine = (NSInteger)ceil(NSHeight(firstLineRect));
			
		}
		
		CFRelease(path);
		CFRelease(frameref);
	}
	
	RSMultiLineRendererMeasurements *measurements = [RSMultiLineRendererMeasurements measurementsWithHeight:height heightOfFirstLine:heightOfFirstLine];
	return measurements;
}


- (void)renderTextInRect:(CGRect)r {
	
	self.rect = r;
	
	CGContextRef context = [NSGraphicsContext currentContext].CGContext;
	CGContextSaveGState(context);
	
	CGContextSetFillColorWithColor(context, self.backgroundColor.CGColor);
	CGContextFillRect(context, r);
	
	CGContextSetShouldSmoothFonts(context, true);
	
	CTFrameDraw(self.frameref, context);
	
	CGContextRestoreGState(context);
}


- (CTFrameRef)frameref {
	
	if (_frameref) {
		return _frameref;
	}
	
	CGPathRef path = CGPathCreateWithRect(self.rect, NULL);
	
	_frameref = CTFramesetterCreateFrame(self.framesetter, CFRangeMake(0, (CFIndex)(self.title.length)), path, NULL);
	
	CFRelease(path);
	
	return _frameref;
}

@end
