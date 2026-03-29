# Contributing

We welcome contributions — but it’s **really important to ask first** before working on a new feature or bug fix. Just because the app is open source doesn’t mean we add features just whenever someone codes one up. The app is planned the same way it would be if it weren’t open source. (See NetNewsWire [milestones](https://github.com/Ranchero-Software/NetNewsWire/milestones).)

Also: just because a ticket exists doesn’t mean we’re going to implement a fix or feature. Or not now, or not before some other things happen first.

Do not open a PR first. Ask first! If you open a PR, it will be ignored or closed without comment. Even a draft PR.

Here’s how to contribute:

1. Find or file a ticket describing the bug you want to fix or feature you want to add.
2. On the [Discourse forum](https://discourse.netnewswire.com/), add yourself to the [netnewswire-dev group](https://discourse.netnewswire.com/g/netnewswire-dev), which gives you access to the [Work category](https://discourse.netnewswire.com/c/work/12). Add a new topic to the Work category for discussion (which may or may not include implementation discussion). **This is very important, because there might be things you need to know before you start work.** We might also, for whatever reason, not want to do that feature, not do it this year, do it in a very different way, or whatever. Or it may be that a given bug fix should come after some other refactoring, for instance.
3. Once approved, then go for it. Write the code, then do a pull request. We’ll either have comments or we’ll merge it. (We might revise it afterward, of course.)

By participating, you agree to follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## LLM guidelines

We’re not accepting any documentation PRs at all, since we won’t accept any LLM-generated documentation, and we have no way to know whether or not a document is written with the help of an LLM.

We do accept code written with the help of an LLM, but we require that a PR should note that an LLM was used. Could be in the commit message, could be in a comment — either way is fine. (The point is that it should be obvious to Brent and any reviewers.)

All code written with the help of an LLM must be at or above the level of hand-written code. The author must review the code thoroughly before creating a PR, just as if they had written every line — because the author is responsible for every line.

In other words: LLMs should be used to *raise* the level of code quality, not lower it.

## Notes

It’s important that the pull request merge cleanly with `main`. It must add no warnings.

You should have read the [coding guidelines](Technotes/CodingGuidelines.md) first. If your code doesn’t follow the guidelines, we will likely suggest revising it.

Patience may be required at times. Brent isn’t always available — just because of life. 🐥
