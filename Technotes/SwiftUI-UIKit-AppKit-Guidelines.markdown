#  When to use SwiftUI, UIKit, and AppKit

## iOS

Use SwiftUI when possible. There are two cases where you should use UIKit instead:

1. When scrolling performance matters — the timeline, in other words, should not use SwiftUI
2. When SwiftUI can’t provide the user experience we want

## macOS

Use AppKit and .xib files. Avoid SwiftUI. Avoid storyboard files too — use .xib files.

Use Auto Layout in .xib files. Avoid writing Auto Layout constraints in code (sometimes it’s inevitable: if so, use `needsUpdateConstraints` and `updateConstraints`).
