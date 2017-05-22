//
//  RSMacroProcessor.m
//  RSCore
//
//  Created by Brent Simmons on 10/26/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

#import "RSMacroProcessor.h"


@interface RSMacroProcessor ()

@property (nonatomic, readonly) NSString *template;
@property (nonatomic, readonly) NSDictionary *substitutions;
@property (nonatomic, readonly) NSString *macroStart;
@property (nonatomic, readonly) NSString *macroEnd;
@property (nonatomic, readonly) NSUInteger numberOfMacroStartCharacters;
@property (nonatomic, readonly) NSUInteger numberOfMacroEndCharacters;
@property (nonatomic) NSString *renderedText;

@end


@implementation RSMacroProcessor

#pragma mark - Class Methods

+ (NSString *)renderedTextWithTemplate:(NSString *)templateString substitutions:(NSDictionary *)substitutions macroStart:(NSString *)macroStart macroEnd:(NSString *)macroEnd {

	RSMacroProcessor *macroProcessor = [[self alloc] initWithTemplate:templateString substitutions:substitutions macroStart:macroStart macroEnd:macroEnd];
	return macroProcessor.renderedText;
}


#pragma mark - Init

- (instancetype)initWithTemplate:(NSString *)templateString substitutions:(NSDictionary *)substitutions macroStart:(NSString *)macroStart macroEnd:(NSString *)macroEnd {

	self = [super init];
	if (!self) {
		return nil;
	}

	_template = templateString;
	_substitutions = substitutions;
	_macroStart = macroStart;
	_macroEnd = macroEnd;
	_numberOfMacroStartCharacters = _macroStart.length;
	_numberOfMacroEndCharacters = _macroEnd.length;

	return self;
}

#pragma mark - Accessors

- (NSString *)renderedText {

	if (!_renderedText) {
		_renderedText = [self processMacros];
	}

	return _renderedText;
}


#pragma mark - Private

- (NSUInteger)indexOfString:(NSString *)s beforeIndex:(NSUInteger)ix inString:(NSString *)stringToSearch {

	if (ix < s.length) {
		return NSNotFound;
	}

	NSRange range = [stringToSearch rangeOfString:s options:NSBackwardsSearch range:NSMakeRange(0, ix)];
	if (range.length < s.length) {
		return NSNotFound;
	}

	return range.location;
}


- (NSString *)processMacros {

	NSMutableString *s = [self.template mutableCopy];

	NSUInteger lastIndexOfMacroStart = s.length;

	while (true) {

		NSUInteger ixMacroEnd = [self indexOfString:self.macroEnd beforeIndex:lastIndexOfMacroStart inString:s];
		if (ixMacroEnd == NSNotFound) {
			break;
		}

		NSUInteger ixMacroStart = [self indexOfString:self.macroStart beforeIndex:ixMacroEnd inString:s];
		if (ixMacroStart == NSNotFound) {
			break;
		}

		NSRange range = NSMakeRange(ixMacroStart, (ixMacroEnd - ixMacroStart) + self.numberOfMacroEndCharacters);
		
		NSRange keyRange = range;
		keyRange.location += self.numberOfMacroStartCharacters;
		keyRange.length -= (self.numberOfMacroStartCharacters + self.numberOfMacroEndCharacters);
		NSString *key = [s substringWithRange:keyRange];

		NSString *substition = [self.substitutions objectForKey:key];
		if (substition) {
			[s replaceCharactersInRange:range withString:substition];
		}

		lastIndexOfMacroStart = ixMacroStart;
	}

	return [s copy];
}

@end
