//
//  NSString+RSParser.m
//  RSParser
//
//  Created by Brent Simmons on 9/25/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

#import "NSString+RSParser.h"
#import <CommonCrypto/CommonDigest.h>




@interface NSScanner (RSParser)

- (BOOL)rs_scanEntityValue:(NSString * _Nullable * _Nullable)decodedEntity;

@end


@implementation NSString (RSParser)

- (BOOL)rsparser_contains:(NSString *)s {

	return [self rangeOfString:s].location != NSNotFound;
}

- (NSString *)rsparser_stringByDecodingHTMLEntities {
	
	@autoreleasepool {
		
		NSScanner *scanner = [[NSScanner alloc] initWithString:self];
		scanner.charactersToBeSkipped = nil;
		NSMutableString *result = [[NSMutableString alloc] init];
		
		while (true) {
			
			NSString *scannedString = nil;
			if ([scanner scanUpToString:@"&" intoString:&scannedString]) {
				[result appendString:scannedString];
			}
			if (scanner.isAtEnd) {
				break;
			}
			NSUInteger savedScanLocation = scanner.scanLocation;
			
			NSString *decodedEntity = nil;
			if ([scanner rs_scanEntityValue:&decodedEntity]) {
				[result appendString:decodedEntity];
			}
			else {
				[result appendString:@"&"];
				scanner.scanLocation = savedScanLocation + 1;
			}
			
			if (scanner.isAtEnd) {
				break;
			}
		}
		
		if ([self isEqualToString:result]) {
			return self;
		}
		return [result copy];
	}
}


static NSDictionary *RSEntitiesDictionary(void);
static NSString *RSParserStringWithValue(uint32_t value);

- (NSString * _Nullable)rs_stringByDecodingEntity {
	
	// self may or may not have outer & and ; characters.
	
	NSMutableString *s = [self mutableCopy];
	
	if ([s hasPrefix:@"&"]) {
		[s deleteCharactersInRange:NSMakeRange(0, 1)];
	}
	if ([s hasSuffix:@";"]) {
		[s deleteCharactersInRange:NSMakeRange(s.length - 1, 1)];
	}
	
	NSDictionary *entitiesDictionary = RSEntitiesDictionary();
	
	NSString *decodedEntity = entitiesDictionary[self];
	if (decodedEntity) {
		return decodedEntity;
	}
	
	if ([s hasPrefix:@"#x"] || [s hasPrefix:@"#X"]) { // Hex
		NSScanner *scanner = [[NSScanner alloc] initWithString:s];
		scanner.charactersToBeSkipped = [NSCharacterSet characterSetWithCharactersInString:@"#xX"];
		unsigned int hexValue = 0;
		if ([scanner scanHexInt:&hexValue]) {
			return RSParserStringWithValue((uint32_t)hexValue);
		}
		return nil;
	}

	else if ([s hasPrefix:@"#"]) {
		[s deleteCharactersInRange:NSMakeRange(0, 1)];
		NSInteger value = s.integerValue;
		if (value < 1) {
			return nil;
		}
		return RSParserStringWithValue((uint32_t)value);
	}

	return nil;
}

- (NSString *)rsparser_stringByEncodingRequiredEntities {
	NSMutableString *result = [NSMutableString string];

	for (NSUInteger i = 0; i < self.length; ++i) {
		unichar c = [self characterAtIndex:i];

		switch (c) {
			case '<':
				[result appendString:@"&lt;"];
				break;
			case '>':
				[result appendString:@"&gt;"];
				break;
			case '&':
				[result appendString:@"&amp;"];
				break;
			default:
				[result appendFormat:@"%C", c];
				break;
		}
	}

	return [result copy];
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
- (NSData *)_rsparser_md5HashData {

	NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];
	unsigned char hash[CC_MD5_DIGEST_LENGTH];
	CC_MD5(data.bytes, (CC_LONG)data.length, hash);

	return [NSData dataWithBytes:(const void *)hash length:CC_MD5_DIGEST_LENGTH];
}
#pragma GCC diagnostic pop

- (NSString *)rsparser_md5Hash {

	NSData *md5Data = [self _rsparser_md5HashData];
	const Byte *bytes = md5Data.bytes;
	return [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]];
}


@end

@implementation NSScanner (RSParser)

- (BOOL)rs_scanEntityValue:(NSString * _Nullable * _Nullable)decodedEntity {
	
	NSString *s = self.string;
	NSUInteger initialScanLocation = self.scanLocation;
	static NSUInteger maxEntityLength = 20; // It’s probably smaller, but this is just for sanity.
	
	while (true) {
		
		unichar ch = [s characterAtIndex:self.scanLocation];
		if ([NSCharacterSet.whitespaceAndNewlineCharacterSet characterIsMember:ch]) {
			break;
		}
		if (ch == ';') {
			if (!decodedEntity) {
				return YES;
			}
			NSString *rawEntity = [s substringWithRange:NSMakeRange(initialScanLocation + 1, (self.scanLocation - initialScanLocation) - 1)];
			*decodedEntity = [rawEntity rs_stringByDecodingEntity];
			self.scanLocation = self.scanLocation + 1;
			return *decodedEntity != nil;
		}
		
		self.scanLocation = self.scanLocation + 1;
		if (self.scanLocation - initialScanLocation > maxEntityLength) {
			break;
		}
		if (self.isAtEnd) {
			break;
		}
	}
	
	return NO;
}

@end

static NSString *RSParserStringWithValue(uint32_t value) {
	// From WebCore's HTMLEntityParser
	static const uint32_t windowsLatin1ExtensionArray[32] = {
		0x20AC, 0x0081, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, // 80-87
		0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x008D, 0x017D, 0x008F, // 88-8F
		0x0090, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, // 90-97
		0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x009D, 0x017E, 0x0178  // 98-9F
	};

	if ((value & ~0x1Fu) == 0x80u) { // value >= 128 && value < 160
		value = windowsLatin1ExtensionArray[value - 0x80];
	}

	value = CFSwapInt32HostToLittle(value);
	
	return [[NSString alloc] initWithBytes:&value length:sizeof(value) encoding:NSUTF32LittleEndianStringEncoding];
}

static NSDictionary *RSEntitiesDictionary(void) {
	
	static NSDictionary *entitiesDictionary = nil;
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		entitiesDictionary = @{
			// Named entities
			@"AElig": @"Æ",
			@"Aacute": @"Á",
			@"Acirc": @"Â",
			@"Agrave": @"À",
			@"Aring": @"Å",
			@"Atilde": @"Ã",
			@"Auml": @"Ä",
			@"Ccedil": @"Ç",
			@"Dstrok": @"Ð",
			@"ETH": @"Ð",
			@"Eacute": @"É",
			@"Ecirc": @"Ê",
			@"Egrave": @"È",
			@"Euml": @"Ë",
			@"Iacute": @"Í",
			@"Icirc": @"Î",
			@"Igrave": @"Ì",
			@"Iuml": @"Ï",
			@"Ntilde": @"Ñ",
			@"Oacute": @"Ó",
			@"Ocirc": @"Ô",
			@"Ograve": @"Ò",
			@"Oslash": @"Ø",
			@"Otilde": @"Õ",
			@"Ouml": @"Ö",
			@"Pi": @"Π",
			@"THORN": @"Þ",
			@"Uacute": @"Ú",
			@"Ucirc": @"Û",
			@"Ugrave": @"Ù",
			@"Uuml": @"Ü",
			@"Yacute": @"Y",
			@"aacute": @"á",
			@"acirc": @"â",
			@"acute": @"´",
			@"aelig": @"æ",
			@"agrave": @"à",
			@"amp": @"&",
			@"apos": @"'",
			@"aring": @"å",
			@"atilde": @"ã",
			@"auml": @"ä",
			@"brkbar": @"¦",
			@"brvbar": @"¦",
			@"ccedil": @"ç",
			@"cedil": @"¸",
			@"cent": @"¢",
			@"copy": @"©",
			@"curren": @"¤",
			@"deg": @"°",
			@"die": @"¨",
			@"divide": @"÷",
			@"eacute": @"é",
			@"ecirc": @"ê",
			@"egrave": @"è",
			@"eth": @"ð",
			@"euml": @"ë",
			@"euro": @"€",
			@"frac12": @"½",
			@"frac14": @"¼",
			@"frac34": @"¾",
			@"gt": @">",
			@"hearts": @"♥",
			@"hellip": @"…",
			@"iacute": @"í",
			@"icirc": @"î",
			@"iexcl": @"¡",
			@"igrave": @"ì",
			@"iquest": @"¿",
			@"iuml": @"ï",
			@"laquo": @"«",
			@"ldquo": @"“",
			@"lsquo": @"‘",
			@"lt": @"<",
			@"macr": @"¯",
			@"mdash": @"—",
			@"micro": @"µ",
			@"middot": @"·",
			@"ndash": @"–",
			@"not": @"¬",
			@"ntilde": @"ñ",
			@"oacute": @"ó",
			@"ocirc": @"ô",
			@"ograve": @"ò",
			@"ordf": @"ª",
			@"ordm": @"º",
			@"oslash": @"ø",
			@"otilde": @"õ",
			@"ouml": @"ö",
			@"para": @"¶",
			@"pi": @"π",
			@"plusmn": @"±",
			@"pound": @"£",
			@"quot": @"\"",
			@"raquo": @"»",
			@"rdquo": @"”",
			@"reg": @"®",
			@"rsquo": @"’",
			@"sect": @"§",
			@"shy": RSParserStringWithValue(173),
			@"sup1": @"¹",
			@"sup2": @"²",
			@"sup3": @"³",
			@"szlig": @"ß",
			@"thorn": @"þ",
			@"times": @"×",
			@"trade": @"™",
			@"uacute": @"ú",
			@"ucirc": @"û",
			@"ugrave": @"ù",
			@"uml": @"¨",
			@"uuml": @"ü",
			@"yacute": @"y",
			@"yen": @"¥",
			@"yuml": @"ÿ",
			@"infin": @"∞",
			@"nbsp": RSParserStringWithValue(160)
		};
	});
	
	return entitiesDictionary;
}
