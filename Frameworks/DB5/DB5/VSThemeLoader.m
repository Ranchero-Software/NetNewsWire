//
//  VSThemeLoader.h
//  Q Branch LLC
//
//  Created by Brent Simmons on 6/26/13.
//  Copyright (c) 2012 Q Branch LLC. All rights reserved.
//


#import "VSThemeLoader.h"
#import "VSTheme.h"


@interface VSThemeLoader ()

@property (nonatomic, strong, readwrite) VSTheme *defaultTheme;
@property (nonatomic, strong, readwrite) NSArray *themes;
@end


@implementation VSThemeLoader


- (instancetype)init {

	NSString *themesFilePath = [[NSBundle mainBundle] pathForResource:@"DB5" ofType:@"plist"];
	return [self initWithFilepath:themesFilePath];
}


- (instancetype)initWithFilepath:(NSString *)f {

	self = [super init];
	if (!self) {
		return nil;
	}

	NSDictionary *themesDictionary = [NSDictionary dictionaryWithContentsOfFile:f];

	NSMutableArray *themes = [NSMutableArray array];
	for (NSString *oneKey in themesDictionary) {

		VSTheme *theme = [[VSTheme alloc] initWithDictionary:themesDictionary[oneKey]];
		if ([[oneKey lowercaseString] isEqualToString:@"default"])
			_defaultTheme = theme;
		theme.name = oneKey;
		[themes addObject:theme];
	}

	for (VSTheme *oneTheme in themes) { /*All themes inherit from the default theme.*/
		if (oneTheme != _defaultTheme)
			oneTheme.parentTheme = _defaultTheme;
	}

	_themes = themes;

	return self;
}


- (VSTheme *)themeNamed:(NSString *)themeName {

	for (VSTheme *oneTheme in self.themes) {
		if ([themeName isEqualToString:oneTheme.name])
			return oneTheme;
	}

	return nil;
}

@end
