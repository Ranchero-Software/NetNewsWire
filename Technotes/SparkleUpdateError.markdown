# “Can’t Update” Error

If NetNewsWire’s auto-updater gives you an error that it can’t be updated, do this:

* Cancel the update if you still need to
* Quit NetNewsWire
* Move NetNewsWire to your Applications folder (or to your `~/Applications/` folder)
* Launch NetNewsWire
* Check for Updates again

That should do the trick!

## The problem

If you’re running the app from your `~/Downloads` folder, then the system has placed your app under quarantine — which means the app can’t update itself.

Once you move the app to another folder, the quarantine is lifted, and the app can update itself.

This *does* require your manual intervention: it‘s not something NetNewsWire can do for you automatically.

For more info, [see this bug](https://github.com/brentsimmons/NetNewsWire/issues/213).
