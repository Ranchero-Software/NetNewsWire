//
//  RSMultiLineView.m
//  RSTextDrawing
//
//  Created by Brent Simmons on 5/27/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import RSCore;
#import "RSMultiLineView.h"
#import "RSMultiLineRenderer.h"
#import "RSMultiLineRendererMeasurements.h"


@interface RSMultiLineView ()

@property (nonatomic) RSMultiLineRenderer *renderer;
@property (nonatomic) NSSize intrinsicSize;
@property (nonatomic) BOOL intrinsicSizeIsValid;
@property (nonatomic) RSMultiLineRenderer *selectedRenderer;
@property (nonatomic) NSAttributedString *selectedAttributedStringValue;

@end

static NSAttributedString *emptyAttributedString = nil;

@implementation RSMultiLineView


- (instancetype)initWithFrame:(NSRect)frame {
	
	self = [super initWithFrame:frame];
	if (!self) {
		return nil;
	}
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		emptyAttributedString = [[NSAttributedString alloc] initWithString:@""];
	});

	_renderer = [RSMultiLineRenderer rendererWithAttributedTitle:emptyAttributedString];
	
	return self;
}


- (void)setRenderer:(RSMultiLineRenderer *)renderer {
	
	if (_renderer == renderer) {
		return;
	}
	_renderer = renderer;
	
	[self invalidateIntrinsicContentSize];
	self.needsDisplay = YES;
}

- (RSMultiLineRenderer *)selectedRenderer {
	
	if (_selectedRenderer) {
		return _selectedRenderer;
	}
	
	_selectedRenderer = [RSMultiLineRenderer rendererWithAttributedTitle:self.selectedAttributedStringValue];
	_selectedRenderer.backgroundColor = NSColor.alternateSelectedControlColor;
	return _selectedRenderer;
}


- (void)setSelected:(BOOL)selected {
	
	_selected = selected;
	self.needsDisplay = YES;
}


- (void)setEmphasized:(BOOL)emphasized {
	
	_emphasized = emphasized;
	self.needsDisplay = YES;
}


- (NSAttributedString *)selectedAttributedStringValue {
	
	if (!self.attributedStringValue) {
		return emptyAttributedString;
	}
	
	NSMutableAttributedString *s = [self.attributedStringValue mutableCopy];
	[s addAttribute:NSForegroundColorAttributeName value:NSColor.alternateSelectedControlTextColor range:NSMakeRange(0, s.string.length)];
	_selectedAttributedStringValue = s;
	
	return _selectedAttributedStringValue;
}


- (void)setAttributedStringValue:(NSAttributedString *)attributedStringValue {
	
	if (_attributedStringValue == attributedStringValue) {
		return;
	}
	_attributedStringValue = attributedStringValue;
	
	self.selectedAttributedStringValue = nil;
	self.selectedRenderer = nil;
	
	self.renderer = [RSMultiLineRenderer rendererWithAttributedTitle:attributedStringValue];
}


- (RSMultiLineRendererMeasurements *)measurements {
	
	return [self.renderer measurementsForWidth:NSWidth(self.frame)];
}


- (void)invalidateIntrinsicContentSize {
	
	self.intrinsicSizeIsValid = NO;
}


- (NSSize)intrinsicContentSize {
	
	if (!self.intrinsicSizeIsValid) {
		self.intrinsicSize = NSMakeSize(NSWidth(self.frame), self.measurements.height);
		self.intrinsicSizeIsValid = YES;
	}
	return self.intrinsicSize;
}


- (void)setFrameSize:(NSSize)newSize {
	
	[self invalidateIntrinsicContentSize];
	[super setFrameSize:newSize];
}


- (NSMenu *)menuForEvent:(NSEvent *)event {

	NSTableView *tableView = [self rs_enclosingTableView];
	if (tableView) {
		return [tableView menuForEvent:event];
	}
	return nil;
}


- (void)drawRect:(NSRect)r {
	
	if (self.selected) {
		
		if (self.emphasized) {
			[self.selectedRenderer renderTextInRect:self.bounds];
		}
		else {
			NSColor *savedBackgroundColor = self.renderer.backgroundColor;
			self.renderer.backgroundColor = NSColor.secondarySelectedControlColor;
			[self.renderer renderTextInRect:self.bounds];
			self.renderer.backgroundColor = savedBackgroundColor;
		}
	}
	
	else {
		[self.renderer renderTextInRect:self.bounds];
	}
}

@end
