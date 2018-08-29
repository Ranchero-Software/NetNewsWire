# Git Submodules

NetNewsWire uses [Git submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules) to include shared frameworks. At this writing (June 2018) they are DB5, RSCore, RSDatabase, RSWeb, RSTree, and RSParser.

After your first checkout:

	git submodule init
	git submodule update

To add a submodule:

	git submodule add https://github.com/username/path

(It’s unlikely you’ll need to do that. Adding a submodule is done super-rarely, if ever, and it’s Brent’s call.)

To update all submodules to their latest commits:

	git submodule foreach git pull origin master

