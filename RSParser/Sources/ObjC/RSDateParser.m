//
//  RSDateParser.m
//  RSParser
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//


#import "RSDateParser.h"
#import <time.h>


typedef struct {
	const char *abbreviation;
	const NSInteger offsetHours;
	const NSInteger offsetMinutes;
} RSTimeZoneAbbreviationAndOffset;


#define kNumberOfTimeZones 96

static const RSTimeZoneAbbreviationAndOffset timeZoneTable[kNumberOfTimeZones] = {
	{"GMT", 0, 0}, //Most common at top, for performance
	{"PDT", -7, 0},		{"PST", -8, 0},		{"EST", -5, 0},		{"EDT", -4, 0},
	{"MDT", -6, 0},		{"MST", -7, 0},		{"CST", -6, 0},		{"CDT", -5, 0},
	{"ACT", -8, 0},		{"AFT", 4, 30},		{"AMT", 4, 0},		{"ART", -3, 0},
	{"AST", 3, 0},		{"AZT", 4, 0},		{"BIT", -12, 0},	{"BDT", 8, 0},
	{"ACST", 9, 30},	{"AEST", 10, 0},	{"AKST", -9, 0},	{"AMST", 5, 0},
	{"AWST", 8, 0},		{"AZOST", -1, 0},	{"BIOT", 6, 0},		{"BRT", -3, 0},
	{"BST", 6, 0},		{"BTT", 6, 0},		{"CAT", 2, 0},		{"CCT", 6, 30},
	{"CET", 1, 0},		{"CEST", 2, 0},		{"CHAST", 12, 45},	{"ChST", 10, 0},
	{"CIST", -8, 0},	{"CKT", -10, 0},	{"CLT", -4, 0},		{"CLST", -3, 0},
	{"COT", -5, 0},		{"COST", -4, 0},	{"CVT", -1, 0},		{"CXT", 7, 0},
	{"EAST", -6, 0},	{"EAT", 3, 0},		{"ECT", -4, 0},		{"EEST", 3, 0},
	{"EET", 2, 0},		{"FJT", 12, 0},		{"FKST", -4, 0},	{"GALT", -6, 0},
	{"GET", 4, 0},		{"GFT", -3, 0},		{"GILT", 7, 0},		{"GIT", -9, 0},
	{"GST", -2, 0},		{"GYT", -4, 0},		{"HAST", -10, 0},	{"HKT", 8, 0},
	{"HMT", 5, 0},		{"IRKT", 8, 0},		{"IRST", 3, 30},	{"IST", 2, 0},
	{"JST", 9, 0},		{"KRAT", 7, 0},		{"KST", 9, 0},		{"LHST", 10, 30},
	{"LINT", 14, 0},	{"MAGT", 11, 0},	{"MIT", -9, 30},	{"MSK", 3, 0},
	{"MUT", 4, 0},		{"NDT", -2, 30},	{"NFT", 11, 30},	{"NPT", 5, 45},
	{"NT", -3, 30},		{"OMST", 6, 0},		{"PETT", 12, 0},	{"PHOT", 13, 0},
	{"PKT", 5, 0},		{"RET", 4, 0},		{"SAMT", 4, 0},		{"SAST", 2, 0},
	{"SBT", 11, 0},		{"SCT", 4, 0},		{"SLT", 5, 30},		{"SST", 8, 0},
	{"TAHT", -10, 0},	{"THA", 7, 0},		{"UYT", -3, 0},		{"UYST", -2, 0},
	{"VET", -4, 30},	{"VLAT", 10, 0},	{"WAT", 1, 0},		{"WET", 0, 0},
	{"WEST", 1, 0},		{"YAKT", 9, 0},		{"YEKT", 5, 0}
}; /*See http://en.wikipedia.org/wiki/List_of_time_zone_abbreviations for list*/



#pragma mark - Parser

enum {
	RSJanuary = 1,
	RSFebruary,
	RSMarch,
	RSApril,
	RSMay,
	RSJune,
	RSJuly,
	RSAugust,
	RSSeptember,
	RSOctober,
	RSNovember,
	RSDecember
};

static NSInteger nextMonthValue(const char *bytes, NSUInteger numberOfBytes, NSUInteger startingIndex, NSUInteger *finalIndex) {

	/*Months are 1-based -- January is 1, Dec is 12.
	 Lots of short-circuits here. Not strict. GIGO.*/

	NSUInteger i;// = startingIndex;
	NSUInteger numberOfAlphaCharactersFound = 0;
	char monthCharacters[3] = {0, 0, 0};

	for (i = startingIndex; i < numberOfBytes; i++) {

		*finalIndex = i;
		char character = bytes[i];

		BOOL isAlphaCharacter = (BOOL)isalpha(character);
		if (!isAlphaCharacter && numberOfAlphaCharactersFound < 1)
			continue;
		if (!isAlphaCharacter && numberOfAlphaCharactersFound > 0)
			break;

		numberOfAlphaCharactersFound++;
		if (numberOfAlphaCharactersFound == 1) {
			if (character == 'F' || character == 'f')
				return RSFebruary;
			if (character == 'S' || character == 's')
				return RSSeptember;
			if (character == 'O' || character == 'o')
				return RSOctober;
			if (character == 'N' || character == 'n')
				return RSNovember;
			if (character == 'D' || character == 'd')
				return RSDecember;
		}

		monthCharacters[numberOfAlphaCharactersFound - 1] = character;
		if (numberOfAlphaCharactersFound >=3)
			break;
	}

	if (numberOfAlphaCharactersFound < 2)
		return NSNotFound;

	if (monthCharacters[0] == 'J' || monthCharacters[0] == 'j') { //Jan, Jun, Jul
		if (monthCharacters[1] == 'a' || monthCharacters[1] == 'A')
			return RSJanuary;
		if (monthCharacters[1] == 'u' || monthCharacters[1] == 'U') {
			if (monthCharacters[2] == 'n' || monthCharacters[2] == 'N')
				return RSJune;
			return RSJuly;
		}
		return RSJanuary;
	}

	if (monthCharacters[0] == 'M' || monthCharacters[0] == 'm') { //March, May
		if (monthCharacters[2] == 'y' || monthCharacters[2] == 'Y')
			return RSMay;
		return RSMarch;
	}

	if (monthCharacters[0] == 'A' || monthCharacters[0] == 'a') { //April, August
		if (monthCharacters[1] == 'u' || monthCharacters[1] == 'U')
			return RSAugust;
		return RSApril;
	}

	return RSJanuary; //should never get here
}


static NSInteger nextNumericValue(const char *bytes, NSUInteger numberOfBytes, NSUInteger startingIndex, NSUInteger maximumNumberOfDigits, NSUInteger *finalIndex) {

	/*maximumNumberOfDigits has a maximum limit of 4 (for time zone offsets and years).
	 *finalIndex will be the index of the last character looked at.*/

	if (maximumNumberOfDigits > 4)
		maximumNumberOfDigits = 4;

	NSUInteger i = 0;
	NSUInteger numberOfDigitsFound = 0;
	NSInteger digits[4] = {0, 0, 0, 0};

	for (i = startingIndex; i < numberOfBytes; i++) {
		*finalIndex = i;
		BOOL isDigit = (BOOL)isdigit(bytes[i]);
		if (!isDigit && numberOfDigitsFound < 1)
			continue;
		if (!isDigit && numberOfDigitsFound > 0)
			break;
		digits[numberOfDigitsFound] = bytes[i] - 48; // '0' is 48
		numberOfDigitsFound++;
		if (numberOfDigitsFound >= maximumNumberOfDigits)
			break;
	}

	if (numberOfDigitsFound < 1)
		return NSNotFound;
	if (numberOfDigitsFound == 1)
		return digits[0];
	if (numberOfDigitsFound == 2)
		return (digits[0] * 10) + digits[1];
	if (numberOfDigitsFound == 3)
		return (digits[0] * 100) + (digits[1] * 10) + digits[2];
	return (digits[0] * 1000) + (digits[1] * 100) + (digits[2] * 10) + digits[3];
}


static BOOL hasAtLeastOneAlphaCharacter(const char *s) {

	NSUInteger length = strlen(s);
	NSUInteger i = 0;

	for (i = 0; i < length; i++) {
		if (isalpha(s[i]))
			return YES;
	}

	return NO;
}


#pragma mark - Time Zones and offsets

static NSInteger offsetInSecondsForTimeZoneAbbreviation(const char *abbreviation) {

	/*Linear search should be fine. It's a C array, and short (under 100 items).
	 Most common time zones are at the beginning of the array. (We can tweak this as needed.)*/

	NSUInteger i;

	for (i = 0; i < kNumberOfTimeZones; i++) {

		RSTimeZoneAbbreviationAndOffset zone = timeZoneTable[i];
		if (strcmp(abbreviation, zone.abbreviation) == 0) {
			if (zone.offsetHours < 0)
				return (zone.offsetHours * 60 * 60) - (zone.offsetMinutes * 60);
			return (zone.offsetHours * 60 * 60) + (zone.offsetMinutes * 60);
		}
	}

	return 0;
}


static NSInteger offsetInSecondsForOffsetCharacters(const char *timeZoneCharacters) {

	BOOL isPlus = timeZoneCharacters[0] == '+';
	NSUInteger finalIndex = 0;
	NSInteger hours = nextNumericValue(timeZoneCharacters, strlen(timeZoneCharacters), 0, 2, &finalIndex);
	NSInteger minutes = nextNumericValue(timeZoneCharacters, strlen(timeZoneCharacters), finalIndex + 1, 2, &finalIndex);

	if (hours == NSNotFound)
		hours = 0;
	if (minutes == NSNotFound)
		minutes = 0;
	if (hours == 0 && minutes == 0)
		return 0;

	NSInteger seconds = (hours * 60 * 60) + (minutes * 60);
	if (!isPlus)
		seconds = 0 - seconds;
	return seconds;
}


static const char *rs_GMT = "GMT";
static const char *rs_UTC = "UTC";

static NSInteger parsedTimeZoneOffset(const char *bytes, NSUInteger numberOfBytes, NSUInteger startingIndex) {

	/*Examples: GMT Z +0000 -0000 +07:00 -0700 PDT EST
	 Parse into char[5] -- drop any colon characters. If numeric, calculate seconds from GMT.
	 If alpha, special-case GMT and Z, otherwise look up in time zone list to get offset.*/

	char timeZoneCharacters[6] = {0, 0, 0, 0, 0, 0}; //nil-terminated last character
	NSUInteger i = 0;
	NSUInteger numberOfCharactersFound = 0;

	for (i = startingIndex; i < numberOfBytes; i++) {
		char ch = bytes[i];
		if (ch == ':' || ch == ' ')
			continue;
		if (isdigit(ch) || isalpha(ch) || ch == '+' || ch == '-') {
			numberOfCharactersFound++;
			timeZoneCharacters[numberOfCharactersFound - 1] = ch;
		}
		if (numberOfCharactersFound >= 5)
			break;
	}

	if (numberOfCharactersFound < 1 || timeZoneCharacters[0] == 'Z' || timeZoneCharacters[0] == 'z')
		return 0;
	if (strcasestr(timeZoneCharacters, rs_GMT) != nil || strcasestr(timeZoneCharacters, rs_UTC))
		return 0;

	if (hasAtLeastOneAlphaCharacter(timeZoneCharacters))
		return offsetInSecondsForTimeZoneAbbreviation(timeZoneCharacters);
	return offsetInSecondsForOffsetCharacters(timeZoneCharacters);
}


#pragma mark - Date Creation

static NSDate *dateWithYearMonthDayHourMinuteSecondAndTimeZoneOffset(NSInteger year, NSInteger month, NSInteger day, NSInteger hour, NSInteger minute, NSInteger second, NSInteger milliseconds, NSInteger timeZoneOffset) {

	struct tm timeInfo;
	timeInfo.tm_sec = (int)second;
	timeInfo.tm_min = (int)minute;
	timeInfo.tm_hour = (int)hour;
	timeInfo.tm_mday = (int)day;
	timeInfo.tm_mon = (int)(month - 1); //It's 1-based coming in
	timeInfo.tm_year = (int)(year - 1900); //see time.h -- it's years since 1900
	timeInfo.tm_wday = -1;
	timeInfo.tm_yday = -1;
	timeInfo.tm_isdst = -1;
	timeInfo.tm_gmtoff = 0;//[timeZone secondsFromGMT];
	timeInfo.tm_zone = nil;

	NSTimeInterval rawTime = (NSTimeInterval)(timegm(&timeInfo) - timeZoneOffset); //timegm instead of mktime (which uses local time zone)
	if (rawTime == (time_t)ULONG_MAX) {

		/*NSCalendar is super-amazingly-slow (which is partly why RSDateParser exists), so this is used only when the date is far enough in the future (19 January 2038 03:14:08Z on 32-bit systems) that timegm fails. If profiling says that this is a performance issue, then you've got a weird app that needs to work with dates far in the future.*/

		NSDateComponents *dateComponents = [NSDateComponents new];

		dateComponents.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:timeZoneOffset];
		dateComponents.year = year;
		dateComponents.month = month;
		dateComponents.day = day;
		dateComponents.hour = hour;
		dateComponents.minute = minute;
		dateComponents.second = second + (milliseconds / 1000);

		return [[NSCalendar autoupdatingCurrentCalendar] dateFromComponents:dateComponents];
	}

	if (milliseconds > 0) {
		rawTime += ((float)milliseconds / 1000.0f);
	}

	return [NSDate dateWithTimeIntervalSince1970:rawTime];
}


#pragma mark - Standard Formats

static NSDate *RSParsePubDateWithBytes(const char *bytes, NSUInteger numberOfBytes) {

	/*@"EEE',' dd MMM yyyy HH':'mm':'ss ZZZ"
	 @"EEE, dd MMM yyyy HH:mm:ss zzz"
	 @"dd MMM yyyy HH:mm zzz"
	 @"dd MMM yyyy HH:mm ZZZ"
	 @"EEE, dd MMM yyyy"
	 @"EEE, dd MMM yyyy HH:mm zzz"
	 etc.*/

	NSUInteger finalIndex = 0;
	NSInteger day = 1;
	NSInteger month = RSJanuary;
	NSInteger year = 1970;
	NSInteger hour = 0;
	NSInteger minute = 0;
	NSInteger second = 0;
	NSInteger timeZoneOffset = 0;

	day = nextNumericValue(bytes, numberOfBytes, 0, 2, &finalIndex);
	if (day < 1 || day == NSNotFound)
		day = 1;

	month = nextMonthValue(bytes, numberOfBytes, finalIndex + 1, &finalIndex);
	year = nextNumericValue(bytes, numberOfBytes, finalIndex + 1, 4, &finalIndex);
	hour = nextNumericValue(bytes, numberOfBytes, finalIndex + 1, 2, &finalIndex);
	if (hour == NSNotFound)
		hour = 0;

	minute = nextNumericValue(bytes, numberOfBytes, finalIndex + 1, 2, &finalIndex);
	if (minute == NSNotFound)
		minute = 0;

	NSUInteger currentIndex = finalIndex + 1;

	BOOL hasSeconds = (currentIndex < numberOfBytes) && (bytes[currentIndex] == ':');
	if (hasSeconds)
		second = nextNumericValue(bytes, numberOfBytes, currentIndex, 2, &finalIndex);

	currentIndex = finalIndex + 1;
	BOOL hasTimeZone = (currentIndex < numberOfBytes) && (bytes[currentIndex] == ' ');
	if (hasTimeZone)
		timeZoneOffset = parsedTimeZoneOffset(bytes, numberOfBytes, currentIndex);

	return dateWithYearMonthDayHourMinuteSecondAndTimeZoneOffset(year, month, day, hour, minute, second, 0, timeZoneOffset);
}


static NSDate *RSParseW3CWithBytes(const char *bytes, NSUInteger numberOfBytes) {

	/*@"yyyy'-'MM'-'dd'T'HH':'mm':'ss"
	 @"yyyy-MM-dd'T'HH:mm:sszzz"
	 @"yyyy-MM-dd'T'HH:mm:ss'.'SSSzzz"
	 etc.*/

	NSUInteger finalIndex = 0;
	NSInteger day = 1;
	NSInteger month = RSJanuary;
	NSInteger year = 1970;
	NSInteger hour = 0;
	NSInteger minute = 0;
	NSInteger second = 0;
	NSInteger milliseconds = 0;
	NSInteger timeZoneOffset = 0;

	year = nextNumericValue(bytes, numberOfBytes, 0, 4, &finalIndex);
	month = nextNumericValue(bytes, numberOfBytes, finalIndex + 1, 2, &finalIndex);
	day = nextNumericValue(bytes, numberOfBytes, finalIndex + 1, 2, &finalIndex);
	hour = nextNumericValue(bytes, numberOfBytes, finalIndex + 1, 2, &finalIndex);
	minute = nextNumericValue(bytes, numberOfBytes, finalIndex + 1, 2, &finalIndex);
	second = nextNumericValue(bytes, numberOfBytes, finalIndex + 1, 2, &finalIndex);

	NSUInteger currentIndex = finalIndex + 1;
	BOOL hasMilliseconds = (currentIndex < numberOfBytes) && (bytes[currentIndex] == '.');
	if (hasMilliseconds) {
		milliseconds = nextNumericValue(bytes, numberOfBytes, currentIndex, 3, &finalIndex);
		currentIndex = finalIndex + 1;
	}

	timeZoneOffset = parsedTimeZoneOffset(bytes, numberOfBytes, currentIndex);

	return dateWithYearMonthDayHourMinuteSecondAndTimeZoneOffset(year, month, day, hour, minute, second, milliseconds, timeZoneOffset);
}


static BOOL dateIsPubDate(const char *bytes, NSUInteger numberOfBytes) {

	NSUInteger i = 0;

	for (i = 0; i < numberOfBytes; i++) {
		if (bytes[i] == ' ' || bytes[i] == ',')
			return YES;
	}

	return NO;
}


static BOOL dateIsW3CDate(const char *bytes, NSUInteger numberOfBytes) {

	// Something like 2010-11-17T08:40:07-05:00
	// But might be missing T character in the middle.
	// Looks for four digits in a row followed by a -.

	for (NSUInteger i = 0; i < numberOfBytes; i++) {
		char ch = bytes[i];
		if (ch == ' ' || ch == '\r' || ch == '\n' || ch == '\t') {
			continue;
		}
		if (numberOfBytes - i < 5) {
			return NO;
		}
		return isdigit(ch) && isdigit(bytes[i + 1]) && isdigit(bytes[i + 2]) && isdigit(bytes[i + 3]) && bytes[i + 4] == '-';
	}

	return NO;
}

static BOOL numberOfBytesIsOutsideReasonableRange(NSUInteger numberOfBytes) {
	return numberOfBytes < 6 || numberOfBytes > 150;
}


#pragma mark - API

NSDate *RSDateWithBytes(const char *bytes, NSUInteger numberOfBytes) {

	if (numberOfBytesIsOutsideReasonableRange(numberOfBytes))
		return nil;

	if (dateIsW3CDate(bytes, numberOfBytes)) {
		return RSParseW3CWithBytes(bytes, numberOfBytes);
	}
	if (dateIsPubDate(bytes, numberOfBytes))
		return RSParsePubDateWithBytes(bytes, numberOfBytes);

	// Fallback, in case our detection fails.
	return RSParseW3CWithBytes(bytes, numberOfBytes);
}


NSDate *RSDateWithString(NSString *dateString) {

	const char *utf8String = [dateString UTF8String];
	return RSDateWithBytes(utf8String, strlen(utf8String));
}

