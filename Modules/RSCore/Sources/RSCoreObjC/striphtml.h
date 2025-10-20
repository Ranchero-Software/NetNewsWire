//
//  striphtml.h
//  RSCore
//
//  Created by Brent Simmons on 10/20/25.
//  Copyright © 2025 Brent Simmons. All rights reserved.
//

#ifndef striphtml_h
#define striphtml_h

#include <stddef.h>
#include <stdbool.h>

/// Strip HTML tags from a UTF-8 encoded string.
///
/// Remove all HTML tags and everything between script and style tags.
/// Also trim outer whitespace and collapse inner whitespace to single spaces.
///
/// @param input UTF-8 encoded HTML string (does not need to be null-terminated if inputLength is correct)
/// @param inputLength Length of input in bytes
/// @param output Pre-allocated buffer for the result (must be at least inputLength + 1 bytes)
/// @param outputCapacity Maximum bytes that can be written to output (including null terminator)
/// @param maxCharacters Maximum characters to output (0 = no limit)
/// @return Number of bytes written to output (not including null terminator)
size_t stripHTML(const char *input, size_t inputLength,
                 char *output, size_t outputCapacity,
                 size_t maxCharacters);

#endif /* striphtml_h */
