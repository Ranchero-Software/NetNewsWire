//
//  NSEvent+RSCore.h
//  RSCore
//
//  Created by Brent Simmons on 11/14/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

@import AppKit;

NS_ASSUME_NONNULL_BEGIN

extern unichar kDeleteKeyCode;

@interface NSEvent (RSCore)

- (void)rs_getCommandKeyDown:(BOOL *)commandKeyDown optionKeyDown:(BOOL *)optionKeyDown controlKeyDown:(BOOL *)controlKeyDown shiftKeyDown:(BOOL *)shiftKeyDown;

- (BOOL)rs_keyIsModified;

- (unichar)rs_unmodifiedCharacter; //The one and only key pressed, if just one. NSNotFound otherwise.

- (nullable NSString *)rs_unmodifiedCharacterString; // The one and only key, if just one.

@end

NS_ASSUME_NONNULL_END
