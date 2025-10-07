# Why NetNewsWire Is Not a Web App

[Tim Bray writes](https://indieweb.social/@timbray@cosocial.ca/115311601617081367), on Mastodon, I think correctly:

> The canceling of ICEBlock is more evidence, were any needed, that the Web is the platform of the future, the only platform without a controlling vendor.  Anything controversial should be available through a pure browser interface.

This is not the first time I’ve had reason to think about this — I think about issues of tech freedom every day, and I still bristle, after all these years (now more than ever), at having to publish NetNewsWire for iOS through the App Store. (The Mac version has no such requirement — it’s available via the [website](https://netnewswire.com/), and I have no plans to ever offer it via the Mac App Store.)

But what if I wanted to do a web app, in addition to or instead of a native app?

I can picture a future, as I bet you can, where RSS readers aren’t allowed on any app store, and we’re essentially required to use billionaire-owned social media and platform-owned news apps.

But there are issues with making NetNewsWire a web app.

### Money

I [explain in this post](https://inessential.com/2023/02/20/on_not_taking_money_for_netnewswire.html) that NetNewsWire has almost no expenses at all. The biggest expense is my Apple developer membership, and I pay just a little bit to host some websites. It adds up to a couple hundred bucks a year.

If it were a web app instead, I could drop the developer membership, but I’d have to pay way more money for web and database hosting. Probably need a CDN too, and who knows what else. (I don’t have recent web app experience, so I don’t even know what my requirements would be, but I’m sure they’d cost substantially more than a couple hundred bucks a year.)

I could charge for NetNewsWire, but that would go against my political goal of making sure there’s a good and *free* RSS reader available to everyone.

I could take donations instead, but that’s never going to add up to enough to cover the costs.

And in either case I’d have to create a way to take money and start up some kind of entity and then do bookkeeping and report money things to the right places — all stuff I don’t have to waste time on right now. I can just work on the app.

Alternately I could create a web app that people would self-host — but there’s no way I could handle the constant support requests for installation issues. There are free self-hosted RSS readers already anyway, and NetNewsWire would be just another one. This also wouldn’t further my goal of making a free RSS reader available to everyone, since only people with the skills and willingness to self-host would do it.

### Protecting Users

Second issue. Right now, if law enforcement comes to me and demands I turn over a given user’s subscriptions list, I can’t. Literally can’t. I don’t have an encrypted version, even — I have nothing at all. The list lives on their machine (iOS or macOS). If they use a syncing system, it lives there too — but I don’t run a syncing system. I don’t have that info and can’t get it.

If that happened, I’d have to pay a lawyer to see if the demand is legit and possibly help me fight it. That’s yet more money and time.

(Could I encrypt the subscription lists on the server? Yes, but the server would have to be able to decrypt it, or else the app couldn’t possibly work. Which means I could decrypt the lists and turn them over.)

### Another type of freedom

Not an issue, exactly, but a thing.

I was 12 years old when I got my first computer, an Apple II Plus, and I’ve never stopped loving the freedom of having my own computer and being able to run whatever the hell I want to.

My computer is *not* a terminal. It’s a world I get to control, and I can use — and, especially, *make* — whatever I want. I’m not stuck using just what’s provided to me on some other machines elsewhere: I’m not dialing into a mainframe or doing the modern equivalent of using only websites that other people control.

A world where everything is on the web and nothing is on the machines that we own is a sad world where we’ve lost a core freedom.

I want to preserve that freedom. I like making apps that show the value of that freedom.

What I want to see happen is for Apple to allow iPhone and iPad users to load — not *sideload*, a term I detest, because it assumes Apple’s side of things — whatever apps they want to. Because those devices are computers.

I get it. It’s not looking good. And even with the much greater freedom for Mac apps there is still always the possibility of being shut down by Apple (by revoking developer memberships, refusing to notarize, or other technical means).

Still, though, I keep at it, because this freedom matters.

But, again…

Apple keeps doing things that make us all feel sick. Removing ICEBlock is just the latest and it won’t be the last. So I am sympathetic to the idea of making web apps, and my brain goes there more often. And if I could solve the problems of money and of protecting users, I’d be way more inclined.
