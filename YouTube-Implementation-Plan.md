# YouTube Inline Video Support - Implementation Plan

## Overview

This document outlines the implementation plan for adding YouTube inline video support to NetNewsWire through a `FeedTransformer` protocol system. The goal is to transform YouTube RSS feeds to embed videos directly in articles without modifying the core database structure.

## Architecture

### Core Components

1. **FeedTransformer Protocol** - Interface for feed transformation logic
2. **YouTubeFeedTransformer** - Concrete implementation for YouTube feeds
3. **FeedTransformerRegistry** - Manager for registering and applying transformers
4. **Integration Points** - Modifications to existing feed processing pipeline

### Design Principles

- **Non-invasive**: No changes to Articles database schema
- **Modular**: Extensible to other video services
- **Account-agnostic**: Works across all account types (Local, Feedbin, Feedly, etc.)
- **Performance-conscious**: Minimal overhead for non-YouTube feeds

## Implementation Steps

### Phase 1: Core Protocol and Infrastructure

#### Step 1.1: Define FeedTransformer Protocol
**File**: `Modules/Account/Sources/Account/FeedTransformer.swift`

```swift
public protocol FeedTransformer {
    /// Determines if this transformer applies to the given feed URL
    func applies(to feedURL: String) -> Bool
    
    /// Corrects the feed URL if needed (e.g., YouTube channel page to RSS feed)
    func correctFeedURL(_ feedURL: String) -> String?
    
    /// Transforms the parsed feed content
    func transform(_ parsedFeed: ParsedFeed) -> ParsedFeed
    
    /// Priority for applying transformers (higher numbers = higher priority)
    var priority: Int { get }
}
```

#### Step 1.2: Create FeedTransformerRegistry
**File**: `Modules/Account/Sources/Account/FeedTransformerRegistry.swift`

```swift
public class FeedTransformerRegistry {
    public static let shared = FeedTransformerRegistry()
    
    private var transformers: [FeedTransformer] = []
    
    public func register(_ transformer: FeedTransformer)
    public func correctFeedURL(_ feedURL: String) -> String
    public func transform(_ parsedFeed: ParsedFeed, feedURL: String) -> ParsedFeed
    private func applicableTransformers(for feedURL: String) -> [FeedTransformer]
}
```

#### Step 1.3: Implement YouTubeFeedTransformer
**File**: `Modules/Account/Sources/Account/YouTubeFeedTransformer.swift`

Features to implement:
- YouTube URL detection (channel pages, feed URLs)
- Feed URL correction (channel page → RSS feed URL)
- Video embedding in article content
- Media RSS parsing for video metadata

### Phase 2: Integration with Feed Processing Pipeline

#### Step 2.1: Integrate with FeedFinder
**File**: `Modules/Account/Sources/Account/FeedFinder/FeedFinder.swift`
**Line**: 48-52

Modify `FeedFinder.find()` to apply URL correction before feed detection:

```swift
// Apply feed transformers for URL correction
let correctedURLString = FeedTransformerRegistry.shared.correctFeedURL(url.absoluteString)
let finalURL = URL(string: correctedURLString) ?? url
```

#### Step 2.2: Integrate with LocalAccountRefresher
**File**: `Modules/Account/Sources/Account/LocalAccount/LocalAccountRefresher.swift`
**Lines**: 118-132

Modify `downloadDidComplete()` to apply transformers before parsing:

```swift
let parserData = ParserData(url: feed.url, data: data)
FeedParser.parse(parserData) { (parsedFeed, error) in
    guard let account = feed.account, let parsedFeed, error == nil else {
        return
    }
    
    // Apply feed transformers
    let transformedFeed = FeedTransformerRegistry.shared.transform(parsedFeed, feedURL: feed.url)
    
    account.update(feed, with: transformedFeed) { result in
        // ... existing code
    }
}
```

#### Step 2.3: Integrate with Account Delegates
Update account delegate implementations to support transformers:

**Files to modify**:
- `Modules/Account/Sources/Account/CloudKit/CloudKitAccountDelegate.swift`
- `Modules/Account/Sources/Account/Feedbin/FeedbinAccountDelegate.swift`
- `Modules/Account/Sources/Account/Feedly/Operations/FeedlyGetStreamContentsOperation.swift`
- Other sync service delegates

### Phase 3: YouTube-Specific Implementation

#### Step 3.1: YouTube URL Detection and Correction
Implement logic to:
- Detect YouTube channel URLs (`youtube.com/channel/`, `youtube.com/c/`, `youtube.com/@username`)
- Convert to RSS feed URLs (`youtube.com/feeds/videos.xml?channel_id=...`)
- Handle playlist URLs if needed

#### Step 3.2: Video Content Transformation
Implement article content transformation:
- Parse Media RSS tags for video metadata
- Generate HTML for video embedding
- Add fallback links for cases where embedding fails
- Preserve original content alongside video embed

#### Step 3.3: HTML Template for Video Embedding
**File**: `Shared/Article Rendering/youtube-embed-template.html`

Create template for YouTube video embedding:
```html
<div class="youtube-video-container">
    <iframe src="https://www.youtube.com/embed/{VIDEO_ID}" 
            frameborder="0" 
            allowfullscreen>
    </iframe>
    <div class="video-fallback">
        <a href="{VIDEO_URL}">Watch on YouTube: {VIDEO_TITLE}</a>
    </div>
</div>
```

### Phase 4: RSParser Module Enhancement

#### Step 4.1: Media RSS Support
**File**: `Modules/RSParser/Sources/Swift/Items/ParsedItem.swift`

Add media content fields:
```swift
public let mediaContent: [MediaContent]?
public let mediaThumbnail: MediaThumbnail?
```

#### Step 4.2: Update RSS Parser
**Files**: 
- `Modules/RSParser/Sources/ObjC/RSRSSParser.m`
- `Modules/RSParser/Sources/Swift/RSS/RSSInJSONParser.swift`

Add parsing for Media RSS namespaces:
- `<media:content>`
- `<media:thumbnail>`
- `<media:description>`

### Phase 5: UI and Rendering Integration

#### Step 5.1: Article Renderer Updates
**File**: `Shared/Article Rendering/ArticleRenderer.swift`

No changes needed - transformers work at feed level, article rendering remains unchanged.

#### Step 5.2: CSS Styling
**File**: `Shared/Article Rendering/style.css`

Add CSS for video containers:
```css
.youtube-video-container {
    margin: 1em 0;
    position: relative;
    padding-bottom: 56.25%; /* 16:9 aspect ratio */
}

.youtube-video-container iframe {
    position: absolute;
    width: 100%;
    height: 100%;
}
```

## Testing Strategy

NetNewsWire has a robust existing test infrastructure that can be leveraged extensively for the YouTube feature implementation.

### Existing Test Infrastructure

#### **Automated Test Suite**
- **Test Plans**: `NetNewsWire.xctestplan` and `NetNewsWire-iOS.xctestplan` provide organized test execution
- **Build Scripts**: `./buildscripts/build_and_test.sh` runs full build and test automation across macOS/iOS
- **CI Integration**: Automated testing with proper platform coverage and toolchain setup

#### **Module Test Suites**
1. **RSParserTests** - Feed parsing functionality (most relevant for transformers)
2. **AccountTests** - Account management with extensive mock service patterns  
3. **RSCoreTests, RSWebTests, RSDatabaseTests** - Supporting infrastructure
4. **NetNewsWireTests** - App-level integration tests

### Unit Tests (Leverage Existing Patterns)

#### **1. FeedTransformer Protocol Tests**
**Location**: `Modules/Account/Tests/AccountTests/FeedTransformerTests.swift`

Following existing Account test patterns:
```swift
class FeedTransformerTests: XCTestCase {
    
    func testYouTubeURLDetection() {
        let transformer = YouTubeFeedTransformer()
        XCTAssertTrue(transformer.applies(to: "https://youtube.com/channel/UCtest"))
        XCTAssertTrue(transformer.applies(to: "https://youtube.com/@username"))
        XCTAssertFalse(transformer.applies(to: "https://example.com/feed.xml"))
    }
    
    func testFeedURLCorrection() {
        let transformer = YouTubeFeedTransformer()
        let corrected = transformer.correctFeedURL("https://youtube.com/channel/UCtest")
        XCTAssertEqual(corrected, "https://youtube.com/feeds/videos.xml?channel_id=UCtest")
    }
    
    func testRegistryPriority() {
        let registry = FeedTransformerRegistry.shared
        registry.register(YouTubeFeedTransformer())
        // Test transformer ordering and application
    }
}
```

#### **2. RSParser Integration Tests**
**Location**: `Modules/RSParser/Tests/RSParserTests/YouTubeParserTests.swift`

Using existing parser test patterns:
```swift
class YouTubeParserTests: XCTestCase {
    
    func testYouTubeFeedParsing() {
        let d = parserData("YouTubeChannelFeed", "xml", "https://youtube.com/feeds/videos.xml?channel_id=test")
        let parsedFeed = try! FeedParser.parse(d)
        
        let transformer = YouTubeFeedTransformer()
        let transformedFeed = transformer.transform(parsedFeed)
        
        XCTAssertTrue(transformedFeed.items.first?.contentHTML?.contains("youtube.com/embed"))
    }
    
    func testMediaRSSParsing() {
        let d = parserData("YouTubeMediaRSS", "xml", "https://youtube.com/feeds/videos.xml?channel_id=test")
        let parsedFeed = try! FeedParser.parse(d)
        
        guard let item = parsedFeed.items.first else {
            XCTFail("No items found")
            return
        }
        
        XCTAssertNotNil(item.mediaContent)
        XCTAssertNotNil(item.mediaThumbnail)
    }
    
    // Performance test following existing patterns
    func testYouTubeTransformationPerformance() {
        let d = parserData("YouTubeChannelFeed", "xml", "https://youtube.com/feeds/videos.xml?channel_id=test")
        let parsedFeed = try! FeedParser.parse(d)
        let transformer = YouTubeFeedTransformer()
        
        self.measure {
            let _ = transformer.transform(parsedFeed)
        }
    }
}
```

#### **3. LocalAccountRefresher Integration Tests**
**Location**: `Modules/Account/Tests/AccountTests/LocalAccountRefresherTransformerTests.swift`

```swift
class LocalAccountRefresherTransformerTests: XCTestCase {
    
    func testRefresherAppliesTransformers() {
        // Mock feed download and verify transformers are applied
        // Use existing TestTransport patterns from Account tests
    }
    
    func testTransformerErrorHandling() {
        // Test transformer failures don't break feed refresh
    }
}
```

### Test Data Resources

#### **RSParser Test Resources**
**Directory**: `Modules/RSParser/Tests/RSParserTests/Resources/`

Leverage existing resource structure (note: `YouTubeTheVolvoRocks.html` already exists):

```
Resources/
├── YouTubeChannelFeed.xml          # Sample YouTube RSS feed
├── YouTubeMediaRSS.xml             # Feed with Media RSS elements  
├── YouTubeChannelPage.html         # Channel page for URL correction
├── YouTubePlaylistFeed.xml         # Playlist RSS feed
└── YouTubeTransformed.xml          # Expected transformer output
```

#### **Account Test Resources**
**Directory**: `Modules/Account/Tests/AccountTests/JSON/`

Following existing JSON test data pattern:
```
JSON/
├── youtube_feed_correction.json    # URL correction test cases
├── youtube_transformer_config.json # Transformer configuration tests
└── youtube_error_cases.json       # Error handling scenarios
```

### Integration Tests

#### **1. Feed Processing Pipeline Tests**
Extend existing `LocalAccountRefresher` tests:
- Verify transformers integrate with download pipeline
- Test error handling and fallback behavior
- Validate performance impact measurement

#### **2. Account Delegate Compatibility**
Leverage existing Feedly test infrastructure:
- Test transformer compatibility with sync services
- Verify consistent behavior across account types
- Use existing mock service patterns

#### **3. Cross-Platform Testing** 
Use existing test plan infrastructure:
- Both macOS and iOS test plans already configured
- Automated testing via `build_and_test.sh`
- Platform-specific rendering tests

### Performance Testing

#### **Built-in XCTest Performance Framework**
Following existing patterns from `RSSParserTests.swift`:
```swift
func testYouTubeFeedTransformationPerformance() {
    // Target: <10ms additional processing per YouTube feed
    let d = parserData("YouTubeChannelFeed", "xml", "https://youtube.com/...")
    self.measure {
        let parsedFeed = try! FeedParser.parse(d) 
        let _ = FeedTransformerRegistry.shared.transform(parsedFeed, feedURL: d.url)
    }
}
```

### Automated Test Execution

#### **Existing CI Integration**
- Tests run automatically via `./buildscripts/build_and_test.sh`
- Both `NetNewsWire.xctestplan` and `NetNewsWire-iOS.xctestplan` include new test targets
- No additional CI setup required

#### **Test Coverage**
Add transformer tests to existing test plans:
```json
// NetNewsWire.xctestplan - add to testTargets array
{
  "target" : {
    "containerPath" : "container:Modules/Account",
    "identifier" : "AccountTests", 
    "name" : "AccountTests"
  }
}
```

### Manual Testing

1. **Feed Addition**: Test adding YouTube channel URLs through UI
2. **Content Rendering**: Verify video embedding in article view  
3. **Account Types**: Test across Local, Feedbin, Feedly accounts
4. **Performance**: Measure impact on feed refresh times using existing performance monitoring

## Migration and Compatibility

### Existing Feeds
- No changes needed for existing non-YouTube feeds
- YouTube feeds added as channel URLs will be automatically corrected

### Account Compatibility
- Local accounts: Full support via LocalAccountRefresher
- Sync services: Requires testing with each service's feed format

### Rollback Strategy
- Feature can be disabled by clearing transformer registry
- No database migrations required
- Existing articles remain unchanged

## Performance Considerations

### Optimization Strategies
1. **Lazy Loading**: Only apply transformers to feeds that need them
2. **Caching**: Cache corrected URLs and transformation results
3. **Async Processing**: Perform transformations off main thread
4. **Minimal Overhead**: Fast URL detection using string prefixes

### Memory Usage
- Transformer instances are lightweight
- Parsed feed transformations create new objects but original data is released
- Video metadata adds minimal memory overhead

## Security Considerations

### Content Security
- Only embed from trusted YouTube domains
- Validate video IDs to prevent XSS
- Sanitize any user-generated content in video descriptions

### Privacy
- Embedded videos may load external resources
- Consider privacy-enhanced YouTube embeds (youtube-nocookie.com)
- User should be aware of potential tracking

## Future Extensions

### Additional Video Services
The architecture supports extending to other services:
- Vimeo
- Twitch
- Platform-specific podcasting services

### Enhanced Features
- Video thumbnail generation
- Offline video metadata caching
- Custom video player integration

## Implementation Checklist

### Phase 1: Infrastructure & Testing Foundation
- [ ] Define FeedTransformer protocol (`Modules/Account/Sources/Account/FeedTransformer.swift`)
- [ ] Implement FeedTransformerRegistry (`Modules/Account/Sources/Account/FeedTransformerRegistry.swift`)
- [ ] Create YouTubeFeedTransformer skeleton
- [ ] **Add core protocol tests** (`Modules/Account/Tests/AccountTests/FeedTransformerTests.swift`)
- [ ] **Set up test data resources** (leverage existing `Resources/` and `JSON/` directories)
- [ ] **Verify tests run in existing test plans** (both macOS and iOS)

### Phase 2: Integration & Test Coverage
- [ ] Modify FeedFinder for URL correction (`FeedFinder.swift:48`)
- [ ] Update LocalAccountRefresher (`LocalAccountRefresher.swift:118-132`)
- [ ] **Add LocalAccountRefresher integration tests** (`LocalAccountRefresherTransformerTests.swift`)
- [ ] Update account delegates (CloudKit, Feedbin, Feedly)
- [ ] **Verify transformer compatibility with sync services** (extend existing Feedly test patterns)
- [ ] **Add performance benchmarks** (following existing `RSSParserTests` patterns)

### Phase 3: YouTube Implementation & Validation
- [ ] Implement URL detection/correction logic
- [ ] Add video content transformation with Media RSS support
- [ ] Create HTML template for video embedding
- [ ] **Add YouTube-specific parser tests** (`YouTubeParserTests.swift`)
- [ ] **Test with real YouTube feeds** using existing `parserData()` helper
- [ ] **Validate performance targets** (<10ms additional processing per feed)

### Phase 4: Parser Enhancement
- [ ] Add Media RSS support to ParsedItem
- [ ] Update RSS parsers
- [ ] Add parser tests

### Phase 5: UI and Polish
- [ ] Add CSS styling
- [ ] Test rendering across platforms
- [ ] Performance optimization
- [ ] Documentation updates

## Risks and Mitigation

### Technical Risks
1. **YouTube API Changes**: Monitor for RSS feed format changes
2. **Performance Impact**: Profile feed refresh times
3. **Account Compatibility**: Test thoroughly with sync services

### User Experience Risks
1. **Broken Videos**: Provide fallback links
2. **Privacy Concerns**: Document video embedding behavior
3. **Bandwidth Usage**: Consider user preferences for auto-loading videos

## Success Criteria

1. **Functional**: YouTube channel URLs automatically convert to working feeds with embedded videos
2. **Performance**: <10ms additional processing time per YouTube feed
3. **Compatibility**: Works across all supported account types
4. **Reliability**: <1% failure rate for well-formed YouTube feeds
5. **User Experience**: Seamless integration with existing NetNewsWire workflow

## Timeline Estimate

- **Phase 1**: 2-3 days (Infrastructure & Testing Foundation)
  - *Reduced time due to existing test patterns and infrastructure*
- **Phase 2**: 2-3 days (Integration & Test Coverage)  
  - *Parallel development with testing using existing frameworks*
- **Phase 3**: 3-4 days (YouTube Implementation & Validation)
  - *Includes comprehensive testing using established test data patterns*
- **Phase 4**: 2-3 days (Parser Enhancement)
- **Phase 5**: 1-2 days (UI Polish)
- **Testing & Refinement**: 1-2 days *(reduced from 2-3 days)*
  - *Significant time savings due to robust existing test automation*
  - *Automated CI pipeline already handles cross-platform testing*
  - *Performance benchmarks follow established patterns*

**Total Estimated Time**: 11-17 days *(reduced from 12-18 days)*

### **Key Time Savings from Existing Test Infrastructure**
- **Test Setup**: ~1 day saved (existing test plans, build scripts, CI integration)
- **Mock Data**: ~0.5 days saved (existing JSON test resources and patterns)  
- **Performance Testing**: ~0.5 days saved (built-in XCTest performance framework)
- **Cross-Platform Testing**: ~1 day saved (automated via existing test plans)

## Conclusion

This implementation plan provides a solid foundation for adding YouTube inline video support to NetNewsWire while maintaining the application's architectural integrity. The modular design allows for future extension to other video services and ensures minimal impact on existing functionality.