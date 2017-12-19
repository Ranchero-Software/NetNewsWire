//
//  NSString+RSParser.m
//  RSParser
//
//  Created by Brent Simmons on 9/25/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

#import <CommonCrypto/CommonDigest.h>
#import <RSParser/NSString+RSParser.h>


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
static NSString *RSParserStringWithValue(unichar value);

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
	
	if ([s hasPrefix:@"#x"]) { // Hex
		NSScanner *scanner = [[NSScanner alloc] initWithString:s];
		scanner.charactersToBeSkipped = [NSCharacterSet characterSetWithCharactersInString:@"#x"];
		unsigned int hexValue = 0;
		if ([scanner scanHexInt:&hexValue]) {
			return RSParserStringWithValue((unichar)hexValue);
		}
		return nil;
	}

	else if ([s hasPrefix:@"#"]) {
		[s deleteCharactersInRange:NSMakeRange(0, 1)];
		NSInteger value = s.integerValue;
		if (value < 1) {
			return nil;
		}
		return RSParserStringWithValue((unichar)value);
	}

	return nil;
}

- (NSData *)_rsparser_md5HashData {

	NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];
	unsigned char hash[CC_MD5_DIGEST_LENGTH];
	CC_MD5(data.bytes, (CC_LONG)data.length, hash);

	return [NSData dataWithBytes:(const void *)hash length:CC_MD5_DIGEST_LENGTH];
}

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

static NSString *RSParserStringWithValue(unichar value) {
	
	return [[NSString alloc] initWithFormat:@"%C", value];
}

static NSDictionary *RSEntitiesDictionary(void) {
	
	static NSDictionary *entitiesDictionary = nil;
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		entitiesDictionary =
		@{@"#034": @"\"",
		  @"#038": @"&",
		  @"#38": @"&",
		  @"#039": @"'",
		  @"#145": @"‘",
		  @"#146": @"’",
		  @"#147": @"“",
		  @"#148": @"”",
		  @"#149": @"•",
		  @"#150": @"-",
		  @"#151": @"—",
		  @"#153": @"™",
		  @"#160": RSParserStringWithValue(160),
		  @"#161": @"¡",
		  @"#162": @"¢",
		  @"#163": @"£",
		  @"#164": @"?",
		  @"#165": @"¥",
		  @"#166": @"?",
		  @"#167": @"§",
		  @"#168": @"¨",
		  @"#169": @"©",
		  @"#170": @"©",
		  @"#171": @"«",
		  @"#172": @"¬",
		  @"#173": @"¬",
		  @"#174": @"®",
		  @"#175": @"¯",
		  @"#176": @"°",
		  @"#177": @"±",
		  @"#178": @" ",
		  @"#179": @" ",
		  @"#180": @"´",
		  @"#181": @"µ",
		  @"#182": @"µ",
		  @"#183": @"·",
		  @"#184": @"¸",
		  @"#185": @" ",
		  @"#186": @"º",
		  @"#187": @"»",
		  @"#188": @"1/4",
		  @"#189": @"1/2",
		  @"#190": @"1/2",
		  @"#191": @"¿",
		  @"#192": @"À",
		  @"#193": @"Á",
		  @"#194": @"Â",
		  @"#195": @"Ã",
		  @"#196": @"Ä",
		  @"#197": @"Å",
		  @"#198": @"Æ",
		  @"#199": @"Ç",
		  @"#200": @"È",
		  @"#201": @"É",
		  @"#202": @"Ê",
		  @"#203": @"Ë",
		  @"#204": @"Ì",
		  @"#205": @"Í",
		  @"#206": @"Î",
		  @"#207": @"Ï",
		  @"#208": @"?",
		  @"#209": @"Ñ",
		  @"#210": @"Ò",
		  @"#211": @"Ó",
		  @"#212": @"Ô",
		  @"#213": @"Õ",
		  @"#214": @"Ö",
		  @"#215": @"x",
		  @"#216": @"Ø",
		  @"#217": @"Ù",
		  @"#218": @"Ú",
		  @"#219": @"Û",
		  @"#220": @"Ü",
		  @"#221": @"Y",
		  @"#222": @"?",
		  @"#223": @"ß",
		  @"#224": @"à",
		  @"#225": @"á",
		  @"#226": @"â",
		  @"#227": @"ã",
		  @"#228": @"ä",
		  @"#229": @"å",
		  @"#230": @"æ",
		  @"#231": @"ç",
		  @"#232": @"è",
		  @"#233": @"é",
		  @"#234": @"ê",
		  @"#235": @"ë",
		  @"#236": @"ì",
		  @"#237": @"í",
		  @"#238": @"î",
		  @"#239": @"ï",
		  @"#240": @"?",
		  @"#241": @"ñ",
		  @"#242": @"ò",
		  @"#243": @"ó",
		  @"#244": @"ô",
		  @"#245": @"õ",
		  @"#246": @"ö",
		  @"#247": @"÷",
		  @"#248": @"ø",
		  @"#249": @"ù",
		  @"#250": @"ú",
		  @"#251": @"û",
		  @"#252": @"ü",
		  @"#253": @"y",
		  @"#254": @"?",
		  @"#255": @"ÿ",
		  @"#32": @" ",
		  @"#34": @"\"",
		  @"#39": @"",
		  @"#8194": @" ",
		  @"#8195": @" ",
		  @"#8211": @"-",
		  @"#8212": @"—",
		  @"#8216": @"‘",
		  @"#8217": @"’",
		  @"#8220": @"“",
		  @"#8221": @"”",
		  @"#8230": @"…",
		  @"#8617": RSParserStringWithValue(8617),
		  @"AElig": @"Æ",
		  @"Aacute": @"Á",
		  @"Acirc": @"Â",
		  @"Agrave": @"À",
		  @"Aring": @"Å",
		  @"Atilde": @"Ã",
		  @"Auml": @"Ä",
		  @"Ccedil": @"Ç",
		  @"Dstrok": @"?",
		  @"ETH": @"?",
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
		  @"THORN": @"?",
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
		  @"brkbar": @"?",
		  @"brvbar": @"?",
		  @"ccedil": @"ç",
		  @"cedil": @"¸",
		  @"cent": @"¢",
		  @"copy": @"©",
		  @"curren": @"?",
		  @"deg": @"°",
		  @"die": @"?",
		  @"divide": @"÷",
		  @"eacute": @"é",
		  @"ecirc": @"ê",
		  @"egrave": @"è",
		  @"eth": @"?",
		  @"euml": @"ë",
		  @"euro": @"€",
		  @"frac12": @"1/2",
		  @"frac14": @"1/4",
		  @"frac34": @"3/4",
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
		  @"ndash": @"-",
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
		  @"shy": @" ",
		  @"sup1": @" ",
		  @"sup2": @" ",
		  @"sup3": @" ",
		  @"szlig": @"ß",
		  @"thorn": @"?",
		  @"times": @"x",
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
		  @"nbsp": RSParserStringWithValue(160),
		  @"#x21A9": RSParserStringWithValue(8617),
		  @"#xFE0E": RSParserStringWithValue(65038),
		  @"#x2019": RSParserStringWithValue(8217),
		  @"#x2026": RSParserStringWithValue(8230),
		  @"#x201C": RSParserStringWithValue(8220),
		  @"#x201D": RSParserStringWithValue(8221),
		  @"#x2014": RSParserStringWithValue(8212)};
	});
	
	return entitiesDictionary;
}
