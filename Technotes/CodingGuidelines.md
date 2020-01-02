# Coding Guidelines

NetNewsWire’s coding values are, in order:

* No data loss
* No crashes
* No other bugs
* Fast performance
* Developer productivity

These are not in opposition to each other: they work together.

The last one should be of particular interest: work often happens in small bursts, and anyone should be able to make progress on something in 15 minutes.

While making a great app is more important than being productive, being productive is a hugely important part — often underestimated — of making a great app.

### Problem solving

You’ve seen how, in Auto Layout, there is a content compression resistance priority and a content hugging priority?

That’s how we think about problems: the problem compression resistance priority is at max, and the problem hugging priority is also at max.

In other words: solve the problem. Not less than the problem, but not more than the problem — don’t over-generalize.

Similarly: always work at the highest level possible, but not higher and certainly not lower.

### Language

Write new code in Swift 5.

The one exception to this is when dealing with C APIs, which are often much easier to deal with in Objective-C than in Swift. Still, though, this is rare, and is much more likely to be needed in a lower-level framework such as RSParser — it shouldn’t happen at the app level.

Swift code should be “pure” Swift as much as possible: avoid `@objc` except when needed for working with AppKit and other APIs.

Functions should tend to be small. One-liners are a-okay, especially when the function name explains intent more clearly than that one line.

We mostly avoid Swift generics, since generics is an advanced feature that can be relatively hard to understand. We *do* use them, though, when appropriate.

It’s totally okay to use the magic `error` variable when catching errors. In accessors, use of the magic `oldValue` and `newValue` is expected when you need the old or new value.

We use assertions and preconditions (assertions are hit only when running a debug build; preconditions will crash a release build). We also allow force-unwrapping of optionals as a shorthand for a precondition failure, though these should be used sparingly.

Extensions, including private extensions, are used — though we take care not to extend Foundation and AppKit objects too much, lest we end up with our own Cocoa dialect.

Things should be marked private as often as possible. APIs should be exactly what’s needed and not more.

When `@importing`, import `AppKit` rather than `Cocoa`. If you see a case where it’s `Cocoa`, change it to `AppKit`. (Reason: importing Cocoa also imports CoreData, which we aren’t using.)

#### Code organization

Properties go at the top, then functions.

Then extensions for protocol conformances. Then a private extension for any private functions.

Use `// MARK:` as appropriate.

### Composition

#### No subclasses

Subclassing is inevitable — there’s no way out of subclassing things like `NSView` and `NSViewController`, because that’s how AppKit works.

But in all the rest of NetNewsWire, frameworks included, you’d have a hard time finding a class that was designed to be subclassed. It’s rare enough that one would have to look pretty hard to find an example, if there is one at all.

Consider this a hard rule: all Swift classes must be marked as `final`, and all Objective-C classes must be treated as if they were so marked.

#### Protocols and delegates

Protocols and delegates (which are also protocol-conforming) are preferred.

Protocol conformance should be implemented in Swift extensions.

If a delegate protocol is defined in the same file as the delegator class or struct, the protocol interface should be specified before the delegator.

Default implementations in protocols are allowed but ever-so-slightly discouraged. You’ll find several instances in the code, but this is done carefully — we don’t want this to be just another form of inheritance, where you find that you have to bounce back-and-forth between files to figure out what’s going on.

There is one unfortunate case about protocols to note: in Swift you can’t create a Set of some protocol-conforming objects, and we use sets frequently. In those situations another solution — such as a thin object with a delegate — might be better.

#### Small objects

Giant objects with thousands of lines of code are to be avoided. Prefer multiple small objects. It’s easier to focus on a small problem, and small objects are easier to maintain and compose with other objects.

That said, don’t break up a larger object arbitrarily just because it’s large. It may be the honest answer (and it may not be). There should be a logic and reason to the smaller objects.

#### Code repetition

This policy of no-subclasses can lead to some code repetition, or almost-repetition. In small doses, that’s fine, and is better than the alternatives — which tend to be complexifying.

But in larger doses some redesign is needed. It is often the case that breaking up the problem into smaller objects (see above) can solve the repetition problem.

### Model objects

Model objects are plain old objects. We don’t use Core Data or any other system that requires subclassing.

Immutable Swift structs are strongly preferred. They’re worth a little standing-on-your-head to get them — but only a little. Otherwise, use a mutable struct or reference-type object, depending on needs.

### Frameworks

#### Built-in

Don’t fight the built-in frameworks and don’t try to hide them. Let’s not write our own Cocoa dialect.

#### Ours

NetNewsWire is layered into frameworks. There’s an app level and a bunch of frameworks below that. Each framework has its own reason for being. Dependencies between frameworks should be as minimal as possible, but those dependencies do exist.

Some frameworks are not permitted to add dependencies, and should be treated as at the bottom of the cake: RSCore, RSWeb, RSDatabase, RSParser, and RSTree. This simplifies things for us, and makes it easier for us and other people to use these frameworks in other apps.

### User Interface

Stick to stock elements, since this tends to eliminate bugs and future churn. This isn’t always possible, of course, but any custom work should be the minimum possible. We’re in this for the long haul.

Storyboards are preferred to xibs — except when the problem is xib-sized.

Auto layout is used everywhere except in table and outline view cells, where performance is critical.

Stack views are not allowed in table and outline view cells, but they can be useful elsewhere. However, care must be taken that performance (of window resizing, for instance) is not affected. When it is, don’t use a stack view.

Use nil-targeted actions and the responder chain when appropriate.

Use Cocoa bindings extremely rarely — for a checkbox in a preferences window, for instance.

### Notifications and Bindings

Key-Value Observing (KVO) is entirely forbidden. KVO is where the crashing bugs live. (The only possible exception to this is when an Apple API requires KVO, which is rare.)

`NSArrayController` and similar are never used. Binding via code is also not done.

Instead, we use NotificationCenter notifications, and we use Swift’s `didSet` method on accessors.

All notifications must be posted on the main queue.

### Threading

Everything happens on the main thread. Period.

Well, no, not exactly. *Almost* everything happens on the main thread.

The exceptions are things that can be perfectly isolated, such as parsing an RSS feed or fetching from the database. We use `DispatchQueue` to run those in the background, often on a serial queue.

Those things must run without locks — locks are almost completely unused in NetNewsWire. 

Any time a background task with a callback is finished, it must call back on the main queue (except for completely private cases, and then it must be noted in the code).

If this policy leads to a design that blocks the main thread unacceptably, then that design must be re-thought. Ask for help if needed.

### Cleanliness

No code that triggers compiler errors or even warnings may be checked in.

No code that writes to the console may be checked in — console spew is not allowed.

### Profiling

Use Instruments to look for leaks and to do profiling. Instruments is great at finding where the problems actually are, as opposed to where you think they are.

No shipping version gets released without looking for memory leaks.

### Testing

Write unit tests, especially in the lower-level frameworks, and particularly when fixing a bug.

There is never enough test coverage. There should always be more tests.

### Version Control

Every commit message should begin with a present-tense verb.

### Last Thing

Don’t show off. If your code looks like kindergarten code, then _good_.

Points are granted for not trying to amass points.

### Really Last Thing

Tabs vs. spaces? Tabs. We had to pick, and we picked tabs, because it lets people decide their own tab width.
