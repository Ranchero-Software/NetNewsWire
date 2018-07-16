# Dark Mode

https://developer.apple.com/documentation/appkit/supporting_dark_mode_in_your_interface
https://developer.apple.com/videos/play/wwdc2018/210/

Accent colors
Can do preference for content —  see Mail for example
linkColor — see if can use in web view
icons in sidebar should not be vibrant
Use opaque grayscale colors, not opacity, on top of vibrancy
Colors in asset catalogs
	Specify for different  appearances
	High contrast colors
Dynamic system colors
Resolved at draw time
Pictures in asset catalogs
Template images
	contentTintColor new API - NSImageView, NSButton
Render as template image thing in IB
controlAccentColor
color.withSystemEffect(.pressed)
Avoid nonsemantic materials
Semantic materials: popover, menu, sidebar, selection, titlebar, etc.
visualEffectView.material = .popover
Desktop tinted background: window background, underpage, content background
contentBackground default for collection views
Use NSAppearance to override inheritance
.aqua
.darkAqua
effectiveAppearance

Advanced Dark Mode:
  https://developer.apple.com/videos/play/wwdc2018/218/

Build with 10.14 SDK
NSAppearanceCustomization
NSView, NSWindow conforms
NSWindow.appearanceSource

