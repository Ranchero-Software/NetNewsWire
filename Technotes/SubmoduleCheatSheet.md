# Git Submodules

Evergreen uses [Git submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules) to include shared frameworks. At this writing (June 2018) they are DB5, RSCore, RSWeb, RSTree, and RSParser.

To add a submodule:

	git submodule add https://github.com/username/path

(It’s unlikely you’ll need to do that. Adding a submodule is done super-rarely, if ever, and it’s Brent’s call.)

To update a submodule — to get the latest changes:

	git submodule update

I think. Not sure about the above.
