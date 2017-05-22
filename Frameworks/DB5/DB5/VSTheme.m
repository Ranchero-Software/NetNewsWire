//
//  VSTheme.m
//  Q Branch LLC
//
//  Created by Brent Simmons on 6/26/13.
//  Copyright (c) 2012 Q Branch LLC. All rights reserved.
//

#import "VSTheme.h"


#if TARGET_OS_IPHONE

#define VS_COLOR UIColor
#define VS_IMAGE UIImage
#define VS_FONT UIFont
#define VS_EDGE_INSETS UIEdgeInsets
#define VSEdgeInsetsMake UIEdgeInsetsMake

#else /*Mac*/

#define VS_COLOR NSColor
#define VS_IMAGE NSImage
#define VS_FONT NSFont
#define VS_EDGE_INSETS NSEdgeInsets
#define VSEdgeInsetsMake NSEdgeInsetsMake

#endif


static BOOL stringIsEmpty(NSString *s);
static VS_COLOR *colorWithHexString(NSString *hexString);


@interface VSTheme ()

@property (nonatomic, strong) NSDictionary *themeDictionary;
@property (nonatomic, strong) NSMutableDictionary *colorCache;
@property (nonatomic, strong) NSMutableDictionary *colorWithAlphaCache;
@property (nonatomic, strong) NSMutableDictionary *fontCache;

@end


@implementation VSTheme


#pragma mark Init

- (id)initWithDictionary:(NSDictionary *)themeDictionary {

	self = [super init];
	if (self == nil)
		return nil;

	_themeDictionary = themeDictionary;

	_colorCache = [NSMutableDictionary new];
	_fontCache = [NSMutableDictionary new];

	return self;
}


- (id)objectForKey:(NSString *)key {

	id obj = [self.themeDictionary valueForKeyPath:key];
	if (obj == nil && self.parentTheme != nil)
		obj = [self.parentTheme objectForKey:key];
	return obj;
}


- (BOOL)boolForKey:(NSString *)key {

	id obj = [self objectForKey:key];
	if (obj == nil)
		return NO;
	return [obj boolValue];
}


- (NSString *)stringForKey:(NSString *)key {

	id obj = [self objectForKey:key];
	if (obj == nil)
		return nil;
	if ([obj isKindOfClass:[NSString class]])
		return obj;
	if ([obj isKindOfClass:[NSNumber class]])
		return [obj stringValue];
	return nil;
}


- (NSInteger)integerForKey:(NSString *)key {

	id obj = [self objectForKey:key];
	if (obj == nil)
		return 0;
	return [obj integerValue];
}


- (CGFloat)floatForKey:(NSString *)key {

	id obj = [self objectForKey:key];
	if (obj == nil)
		return  0.0f;
	return [obj floatValue];
}


- (NSTimeInterval)timeIntervalForKey:(NSString *)key {

	id obj = [self objectForKey:key];
	if (obj == nil)
		return 0.0;
	return [obj doubleValue];
}


- (VS_IMAGE *)imageForKey:(NSString *)key {

	NSString *imageName = [self stringForKey:key];
	if (stringIsEmpty(imageName))
		return nil;

	return [VS_IMAGE imageNamed:imageName];
}


- (VS_COLOR *)colorForKey:(NSString *)key {

	VS_COLOR *cachedColor = self.colorCache[key];
	if (cachedColor != nil)
		return cachedColor;

	NSString *colorString = [self stringForKey:key];
	VS_COLOR *color = nil;
	if ([colorString isEqualToString:@"clear"])
		color = [VS_COLOR clearColor];
	else
		color = colorWithHexString(colorString);
	if (color == nil)
		color = [VS_COLOR blackColor];

	self.colorCache[key] = color;

	return color;
}


- (VS_COLOR *)colorWithAlphaForKey:(NSString *)key {
	
	VS_COLOR *cachedColor = self.colorWithAlphaCache[key];
	if (cachedColor != nil) {
		return cachedColor;
	}
	
	VS_COLOR *color = [self colorForKey:key];
	CGFloat alpha = [self floatForKey:[key stringByAppendingString:@"Alpha"]];
	color = [color colorWithAlphaComponent:alpha];
	
	self.colorWithAlphaCache[key] = color;
	
	return color;
}


- (VS_EDGE_INSETS)edgeInsetsForKey:(NSString *)key {

	CGFloat left = [self floatForKey:[key stringByAppendingString:@"Left"]];
	CGFloat top = [self floatForKey:[key stringByAppendingString:@"Top"]];
	CGFloat right = [self floatForKey:[key stringByAppendingString:@"Right"]];
	CGFloat bottom = [self floatForKey:[key stringByAppendingString:@"Bottom"]];

	VS_EDGE_INSETS edgeInsets = VSEdgeInsetsMake(top, left, bottom, right);
	return edgeInsets;
}


- (VS_FONT *)fontForKey:(NSString *)key {

	VS_FONT *cachedFont = self.fontCache[key];
	if (cachedFont != nil)
		return cachedFont;

	NSString *fontName = [self stringForKey:key];
	CGFloat fontSize = [self floatForKey:[key stringByAppendingString:@"Size"]];

	if (fontSize < 1.0f)
		fontSize = 15.0f;

	VS_FONT *font = nil;

	if (stringIsEmpty(fontName))
		font = [VS_FONT systemFontOfSize:fontSize];
	else
		font = [VS_FONT fontWithName:fontName size:fontSize];

	if (font == nil)
		font = [VS_FONT systemFontOfSize:fontSize];

	self.fontCache[key] = font;

	return font;
}


- (CGPoint)pointForKey:(NSString *)key {

	CGFloat pointX = [self floatForKey:[key stringByAppendingString:@"X"]];
	CGFloat pointY = [self floatForKey:[key stringByAppendingString:@"Y"]];

	CGPoint point = CGPointMake(pointX, pointY);
	return point;
}


- (CGSize)sizeForKey:(NSString *)key {

	CGFloat width = [self floatForKey:[key stringByAppendingString:@"Width"]];
	CGFloat height = [self floatForKey:[key stringByAppendingString:@"Height"]];

	CGSize size = CGSizeMake(width, height);
	return size;
}


#if TARGET_OS_IPHONE

- (UIViewAnimationOptions)curveForKey:(NSString *)key {

	NSString *curveString = [self stringForKey:key];
	if (stringIsEmpty(curveString))
		return UIViewAnimationOptionCurveEaseInOut;

	curveString = [curveString lowercaseString];
	if ([curveString isEqualToString:@"easeinout"])
		return UIViewAnimationOptionCurveEaseInOut;
	else if ([curveString isEqualToString:@"easeout"])
		return UIViewAnimationOptionCurveEaseOut;
	else if ([curveString isEqualToString:@"easein"])
		return UIViewAnimationOptionCurveEaseIn;
	else if ([curveString isEqualToString:@"linear"])
		return UIViewAnimationOptionCurveLinear;

	return UIViewAnimationOptionCurveEaseInOut;
}


- (VSAnimationSpecifier *)animationSpecifierForKey:(NSString *)key {

	VSAnimationSpecifier *animationSpecifier = [VSAnimationSpecifier new];

	animationSpecifier.duration = [self timeIntervalForKey:[key stringByAppendingString:@"Duration"]];
	animationSpecifier.delay = [self timeIntervalForKey:[key stringByAppendingString:@"Delay"]];
	animationSpecifier.curve = [self curveForKey:[key stringByAppendingString:@"Curve"]];

	return animationSpecifier;
}

#endif


- (VSTextCaseTransform)textCaseTransformForKey:(NSString *)key {

	NSString *s = [self stringForKey:key];
	if (s == nil)
		return VSTextCaseTransformNone;

	if ([s caseInsensitiveCompare:@"lowercase"] == NSOrderedSame)
		return VSTextCaseTransformLower;
	else if ([s caseInsensitiveCompare:@"uppercase"] == NSOrderedSame)
		return VSTextCaseTransformUpper;

	return VSTextCaseTransformNone;
}


- (NSString *)string:(NSString *)s transformedWithTextCaseTransformKey:(NSString *)key {

	VSTextCaseTransform textCaseTransform = [self textCaseTransformForKey:key];
	NSString *transformedString = nil;

	switch (textCaseTransform) {

		case VSTextCaseTransformNone:
			transformedString = s;
			break;

		case VSTextCaseTransformLower:
			transformedString = [s lowercaseString];
			break;

		case VSTextCaseTransformUpper:
			transformedString = [s uppercaseString];
			break;

		default:
			break;
	}

	return transformedString;
}

@end


NSString *VSThemeSpecifierPlusKey(NSString *specifier, NSString *key) {

	return [NSString stringWithFormat:@"%@.%@", specifier, key];
}


#if TARGET_OS_IPHONE

@implementation VSTheme (Animations)


- (void)animateWithAnimationSpecifierKey:(NSString *)animationSpecifierKey animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion {

    VSAnimationSpecifier *animationSpecifier = [self animationSpecifierForKey:animationSpecifierKey];

    [UIView animateWithDuration:animationSpecifier.duration delay:animationSpecifier.delay options:animationSpecifier.curve animations:animations completion:completion];
}

@end


#pragma mark -

@implementation VSAnimationSpecifier

@end

#endif


static BOOL stringIsEmpty(NSString *s) {
	return s == nil || [s length] == 0;
}


static VS_COLOR *colorWithHexString(NSString *hexString) {

	/*Picky. Crashes by design.*/

	if (stringIsEmpty(hexString))
		return [VS_COLOR blackColor];

	NSMutableString *s = [hexString mutableCopy];
	[s replaceOccurrencesOfString:@"#" withString:@"" options:0 range:NSMakeRange(0, [hexString length])];
	CFStringTrimWhitespace((__bridge CFMutableStringRef)s);

	NSString *redString = [s substringToIndex:2];
	NSString *greenString = [s substringWithRange:NSMakeRange(2, 2)];
	NSString *blueString = [s substringWithRange:NSMakeRange(4, 2)];

	unsigned int red = 0, green = 0, blue = 0;
	[[NSScanner scannerWithString:redString] scanHexInt:&red];
	[[NSScanner scannerWithString:greenString] scanHexInt:&green];
	[[NSScanner scannerWithString:blueString] scanHexInt:&blue];

	return [VS_COLOR colorWithRed:(CGFloat)red/255.0f green:(CGFloat)green/255.0f blue:(CGFloat)blue/255.0f alpha:1.0f];
}
