//
//  striphtml.c
//  RSCore
//
//  Created by Brent Simmons on 10/20/25.
//  Copyright © 2025 Ranchero Software, LLC. All rights reserved.
//

#include "striphtml.h"
#include <string.h>
#include <ctype.h>

// Check if we're at the start of a tag (case-insensitive)
static bool matchesTag(const char *p, const char *tag) {
	size_t len = strlen(tag);
	for (size_t i = 0; i < len; i++) {
		if (tolower(p[i]) != tolower(tag[i])) {
			return false;
		}
	}
	return true;
}

// Get the number of bytes in a UTF-8 character starting at p
static inline int utf8CharLength(unsigned char firstByte) {
	if ((firstByte & 0x80) == 0) return 1;      // 0xxxxxxx
	if ((firstByte & 0xE0) == 0xC0) return 2;   // 110xxxxx
	if ((firstByte & 0xF0) == 0xE0) return 3;   // 1110xxxx
	if ((firstByte & 0xF8) == 0xF0) return 4;   // 11110xxx
	return 1; // Invalid, treat as single byte
}

size_t stripHTML(const char *input, size_t inputLength,
                 char *output, size_t outputCapacity,
                 size_t maxCharacters) {

	// Safety checks
	if (input == NULL || output == NULL || outputCapacity == 0) {
		if (output != NULL && outputCapacity > 0) {
			*output = '\0';
		}
		return 0;
	}

	const char *in = input;
	const char *inEnd = input + inputLength;
	char *out = output;
	char *outEnd = output + outputCapacity - 1; // Reserve space for null terminator

	int tagLevel = 0;
	bool inScript = false;
	bool inStyle = false;
	bool lastCharacterWasSpace = true; // Start as true to skip leading whitespace
	size_t charactersAdded = 0;

	while (in < inEnd && out < outEnd) {
		if (maxCharacters > 0 && charactersAdded >= maxCharacters) {
			break;
		}

		unsigned char c = *in;

		// Handle tag opening
		if (c == '<') {
			tagLevel++;

			// Check for script or style tags
			if (in + 7 < inEnd && matchesTag(in + 1, "script")) {
				inScript = true;
			} else if (in + 6 < inEnd && matchesTag(in + 1, "style")) {
				inStyle = true;
			} else if (in + 8 < inEnd && matchesTag(in + 1, "/script")) {
				inScript = false;
			} else if (in + 7 < inEnd && matchesTag(in + 1, "/style")) {
				inStyle = false;
			}
			// Check for block-level tags that should add whitespace
			// Swift preprocessing converts these tags to spaces or newlines, but then
			// the main loop (line 263) converts all whitespace to ' ' anyway.
			// So we can just insert a space for all block-level elements.
			// Tags: <p>, </p>, <div>, </div>, <blockquote>, </blockquote>, <br>, <br/>, <br />, </li>
			if ((in + 2 < inEnd && matchesTag(in + 1, "p>")) ||
			    (in + 3 < inEnd && matchesTag(in + 1, "/p>")) ||
			    (in + 4 < inEnd && matchesTag(in + 1, "div>")) ||
			    (in + 5 < inEnd && matchesTag(in + 1, "/div>")) ||
			    (in + 11 < inEnd && matchesTag(in + 1, "blockquote>")) ||
			    (in + 12 < inEnd && matchesTag(in + 1, "/blockquote>")) ||
			    (in + 3 < inEnd && matchesTag(in + 1, "br>")) ||
			    (in + 4 < inEnd && matchesTag(in + 1, "br/>")) ||
			    (in + 5 < inEnd && matchesTag(in + 1, "br />")) ||
			    (in + 4 < inEnd && matchesTag(in + 1, "/li>"))) {
				if (!lastCharacterWasSpace && out < outEnd) {
					*out++ = ' ';
					lastCharacterWasSpace = true;
					charactersAdded++;
				}
			}

			in++;
			continue;
		}

		// Handle tag closing
		if (c == '>') {
			if (tagLevel > 0) {
				tagLevel--;
			}
			in++;
			continue;
		}

		// Skip content inside tags, scripts, or styles
		if (tagLevel > 0 || inScript || inStyle) {
			in++;
			continue;
		}

		// Handle whitespace
		if (c == ' ' || c == '\t' || c == '\r' || c == '\n') {
			if (!lastCharacterWasSpace) {
				*out++ = ' ';
				lastCharacterWasSpace = true;
				charactersAdded++;
			}
			in++;
			continue;
		}

		// Copy character (handle multi-byte UTF-8)
		lastCharacterWasSpace = false;
		int charLen = utf8CharLength(c);

		// Make sure we have room for the entire UTF-8 character
		if (out + charLen <= outEnd && in + charLen <= inEnd) {
			for (int i = 0; i < charLen; i++) {
				*out++ = *in++;
			}
			charactersAdded++;
		} else {
			break; // Not enough room
		}
	}

	// Trim trailing whitespace
	while (out > output && *(out - 1) == ' ') {
		out--;
	}

	*out = '\0';
	return out - output;
}
