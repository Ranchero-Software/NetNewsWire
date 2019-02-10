# Accessibility

Millions of Mac users have some disability or special needs.  They use screen readers and special
hardware to open up a world that they would otherwise be cut off from.  With a small amount of 
developer work, we can help these users live better lives.

Because NetNewsWire utilizes standard AppKit controls and views, accessibility is already built in.
However this is only a starting point.  Any customized controls and views will have accessibility
work and the application as a whole has to be tested to make sure users can operate if efficiently.

This document lays the groundwork to ensure that NetNewsWire has first class accessibility features.

#### Application Design

- Support full keyboard navigation
- Don’t override built-in keyboard shortcuts (by default)
- Provide alternatives for drag-and-drop operations

#### Audit 

The Accessibility Inspector included with the developer tools includes an automated audit tool.  This
tool didn't find any issues when initially run against NetNewsWire.  Additional auditing will be
performed using the Inspector functionality within the Accessibility Inspector tool.

#### Testing

Manual testing using VoiceOver and Dictation will be done to provide more realworld-like feedback.

#### Reporting Accessibility Issues

The results of the accessibility audit should get filed as separate bugs on GitHub.

#### Success Criteria

- Should be fully navigatable using the keyboard
- Should be fully navigatable using Dictation
- Should be fully discoverable using VoiceOver
