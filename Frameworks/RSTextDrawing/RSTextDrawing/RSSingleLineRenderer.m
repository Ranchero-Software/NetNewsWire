//
//  RSSingleLineRenderer.m
//  RSTextDrawing
//
//  Created by Brent Simmons on 3/3/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#import "RSSingleLineRenderer.h"

static NSMutableDictionary *rendererCache = nil;

@interface RSSingleLineRenderer ()

@property (nonatomic, readonly) NSAttributedString *title;
@property (nonatomic) NSRect rect;
@property (nonatomic, readonly) CTFramesetterRef framesetter;
@property (nonatomic) CTFrameRef frameref;

@end


@implementation RSSingleLineRenderer

@synthesize size = _size;

#pragma mark - Class Methods

+ (void)initialize {
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		rendererCache = [NSMutableDictionary new];
	});
}


+ (instancetype)rendererWithAttributedTitle:(NSAttributedString *)title {
	
	RSSingleLineRenderer *cachedRenderer = rendererCache[title];
	if (cachedRenderer != nil) {
		return cachedRenderer;
	}
	
	RSSingleLineRenderer *renderer = [[RSSingleLineRenderer alloc] initWithAttributedTitle:title];
	rendererCache[title] = renderer;
	return renderer;
}


+ (void)emptyCache {
	
	rendererCache = [NSMutableDictionary new];
}


#pragma mark - Init

- (instancetype)initWithAttributedTitle:(NSAttributedString *)title {
	
	self = [super init];
	if (self == nil) {
		return nil;
	}
	
	_title = title;
	_framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)title);
	_backgroundColor = NSColor.whiteColor;
	
	return self;
}


#pragma mark - Dealloc

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


#pragma mark - Accessors

- (void)setRect:(NSRect)r {
	
	r.origin.y = floor(r.origin.y);
	r.origin.x = floor(r.origin.x);
	r.size.height = floor(r.size.height);
	if (r.size.height > self.size.height) {
		r.size.height = self.size.height;
	}
	r.size.width = floor(r.size.width);
	if (r.size.width > self.size.width) {
		r.size.width = self.size.width;
	}
	
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


- (NSSize)size {
	
	if (NSEqualSizes(_size, NSZeroSize)) {
		_size = [self calculatedSize];
	}
	return _size;
}

#pragma mark - Measurements

static const CGFloat kMaxWidth = 10000.0;
static const CGFloat kMaxHeight = 10000.0;

- (NSSize)calculatedSize {
	
	NSSize size = NSZeroSize;
	
	@autoreleasepool {
		
		CGRect r = CGRectMake(0.0f, 0.0f, kMaxWidth, kMaxHeight);
		CGPathRef path = CGPathCreateWithRect(r, NULL);
		
		CTFrameRef frameref = CTFramesetterCreateFrame(self.framesetter, CFRangeMake(0, (CFIndex)(self.title.length)), path, NULL);
		
		NSArray *lines = (__bridge NSArray *)CTFrameGetLines(frameref);
		
		if (lines.count > 0) {
			
			CTLineRef firstLine = (__bridge CTLineRef)lines[0];
			CGRect firstLineRect = CTLineGetBoundsWithOptions(firstLine, 0);
			CGFloat height = ceil(NSHeight(firstLineRect));
			CGFloat width = ceil(NSWidth(firstLineRect));
			size = NSMakeSize(width, height);
		}
		
		CFRelease(path);
		CFRelease(frameref);
	}
	
	return size;
}


#pragma mark - Drawing

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
