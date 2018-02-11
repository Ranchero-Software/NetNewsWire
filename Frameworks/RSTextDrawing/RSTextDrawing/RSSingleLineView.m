//
//  RSSingleLineView.m
//  RSTextDrawing
//
//  Created by Brent Simmons on 5/27/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import RSCore;
#import "RSSingleLineView.h"
#import "RSSingleLineRenderer.h"

@interface RSSingleLineView ()

@property (nonatomic) RSSingleLineRenderer *renderer;
@property (nonatomic) NSSize intrinsicSize;
@property (nonatomic) BOOL intrinsicSizeIsValid;
@property (nonatomic) RSSingleLineRenderer *selectedRenderer;
@property (nonatomic) NSAttributedString *selectedAttributedStringValue;

@end

static NSAttributedString *emptyAttributedString = nil;

@implementation RSSingleLineView

- (instancetype)initWithFrame:(NSRect)r {
	
	self = [super initWithFrame:r];
	if (!self) {
		return nil;
	}
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		emptyAttributedString = [[NSAttributedString alloc] initWithString:@""];
	});
	
	_renderer = [RSSingleLineRenderer rendererWithAttributedTitle:emptyAttributedString];

	return self;
}


- (void)setAttributedStringValue:(NSAttributedString *)attributedStringValue {
	
	_attributedStringValue = attributedStringValue;
	self.selectedAttributedStringValue = nil;
	self.selectedRenderer = nil;
	
	self.renderer = [RSSingleLineRenderer rendererWithAttributedTitle:attributedStringValue];
}


- (void)setRenderer:(RSSingleLineRenderer *)renderer {

	if (_renderer == renderer) {
		return;
	}
	_renderer = renderer;
	[self invalidateIntrinsicContentSize];
	self.needsDisplay = YES;
}


- (RSSingleLineRenderer *)selectedRenderer {

	if (_selectedRenderer) {
		return _selectedRenderer;
	}

	_selectedRenderer = [RSSingleLineRenderer rendererWithAttributedTitle:self.selectedAttributedStringValue];
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


- (void)invalidateIntrinsicContentSize {
	
	self.intrinsicSizeIsValid = NO;
}


- (NSSize)intrinsicContentSize {
	
	if (!self.intrinsicSizeIsValid) {
		if (!self.attributedStringValue) {
			self.intrinsicSize = NSZeroSize;
		}
		else {
			self.intrinsicSize = ((RSSingleLineRenderer *)(self.renderer)).size;
		}
		self.intrinsicSizeIsValid = YES;
	}
	
	return self.intrinsicSize;
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

