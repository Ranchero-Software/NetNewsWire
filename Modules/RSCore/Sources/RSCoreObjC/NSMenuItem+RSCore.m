//
//  NSMenuItem+RSCore.m
//  RSCore
//
//  Created by Brent Simmons on 1/7/26.
//

#if TARGET_OS_MAC && !TARGET_OS_IPHONE

#import "NSMenuItem+RSCore.h"
#import <objc/runtime.h>

static void *kShouldShowImageKey = &kShouldShowImageKey;

@implementation NSMenuItem (RSCore)

+ (void)rs_disableIcons {

	Method originalMethod = class_getInstanceMethod(self, @selector(image));
	Method swizzledMethod = class_getInstanceMethod(self, @selector(rs_swizzledImage));

	if (originalMethod && swizzledMethod) {
		method_exchangeImplementations(originalMethod, swizzledMethod);
	}
}

- (NSImage *)rs_swizzledImage {

	if (self.rs_shouldShowImage || [self rs_isToolbarItemRepresentation] || self.title.length < 1) {
		// Call the original getter (now swapped to rs_swizzledImage)
		return [self rs_swizzledImage];
	}
	return nil;
}

- (BOOL)rs_isToolbarItemRepresentation {

	// Menu items not attached to any menu are likely toolbar button representations
	return self.menu == nil;
}

- (BOOL)rs_shouldShowImage {

	NSNumber *value = objc_getAssociatedObject(self, kShouldShowImageKey);
	return value.boolValue;
}

- (void)setRs_shouldShowImage:(BOOL)shouldShowImage {

	objc_setAssociatedObject(self, kShouldShowImageKey, @(shouldShowImage), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

#endif
