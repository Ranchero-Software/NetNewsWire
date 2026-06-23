#!/usr/bin/env python3
"""
Find localized literals that are used with more than one `comment:`.

This covers both `NSLocalizedString("literal", comment: "…")` and SwiftUI
`Text("literal", comment: "…")` — they write to the same String Catalog.

A String Catalog keys on the source string, so the same literal with differing
comments makes every build rewrite/merge the comment in Localizable.xcstrings —
producing noisy, flip-flopping diffs. This reports each offending literal, its
distinct comments, and where each one is used.

Comments are compared per catalog: calls that pass `bundle: .module` write to a
module's own catalog, so they're scoped by module and never conflict with the
app's strings.

Run it from anywhere — it scans the whole repo. Exit status is non-zero when
conflicts are found, so it can gate CI.
"""

import os
import re
import sys
from collections import defaultdict

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SKIP_DIRECTORIES = {".git", ".build", "build", "DerivedData", "Pods", ".swiftpm"}

# Matches NSLocalizedString(…) and SwiftUI Text(…) calls of the form
# Call("literal", <anything>, comment: "comment") — including multi-line calls and
# an optional bundle:/tableName: between the two strings. The lookbehind keeps
# `Text(` from matching identifiers that merely end in "Text" (e.g. someText().
# The string bodies allow escaped characters (e.g. \" inside the literal).
LOCALIZED_CALL = re.compile(
	r'(?<![A-Za-z0-9_])'
	r'(?:NSLocalizedString|Text)\(\s*'
	r'"((?:[^"\\]|\\.)*)"'   # 1: the literal (the catalog key)
	r'\s*,\s*'
	r'(.*?)'                 # 2: anything between the literal and the comment
	r'comment:\s*'
	r'"((?:[^"\\]|\\.)*)"',  # 3: the comment
	re.DOTALL)

MODULE_IN_PATH = re.compile(r'/Modules/([^/]+)/')


def swift_files(root):
	for directory, subdirectories, filenames in os.walk(root):
		subdirectories[:] = [name for name in subdirectories if name not in SKIP_DIRECTORIES and not name.startswith(".")]
		for filename in filenames:
			if filename.endswith(".swift"):
				yield os.path.join(directory, filename)


def catalog_scope(path, between_strings):
	"""The catalog a call writes to: a module's own catalog when it passes
	`bundle: .module`, otherwise the app's Localizable.xcstrings."""
	if ".module" in between_strings:
		module = MODULE_IN_PATH.search(path)
		return module.group(1) if module else "Module"
	return "App"


def line_number(text, index):
	return text.count("\n", 0, index) + 1


def collect_comments(root):
	# (scope, literal) -> comment -> ["path:line", …]
	usages = defaultdict(lambda: defaultdict(list))

	for path in swift_files(root):
		try:
			with open(path, encoding="utf-8") as file:
				text = file.read()
		except (OSError, UnicodeDecodeError):
			continue

		for match in LOCALIZED_CALL.finditer(text):
			literal, between_strings, comment = match.group(1), match.group(2), match.group(3)
			scope = catalog_scope(path, between_strings)
			location = "%s:%d" % (os.path.relpath(path, root), line_number(text, match.start()))
			usages[(scope, literal)][comment].append(location)

	return usages


def main():
	usages = collect_comments(REPO_ROOT)
	conflicts = {key: comments for key, comments in usages.items() if len(comments) > 1}

	if not conflicts:
		print("No conflicting localization comments found.")
		return 0

	print("Localization comment conflicts (same string, different comments):\n")
	for scope, literal in sorted(conflicts):
		print('[%s] "%s"' % (scope, literal))
		comments = conflicts[(scope, literal)]
		for comment in sorted(comments):
			print('  "%s"' % comment)
			for location in comments[comment]:
				print("    %s" % location)
		print()

	print("%d conflicting string%s found." % (len(conflicts), "" if len(conflicts) == 1 else "s"))
	return 1


if __name__ == "__main__":
	sys.exit(main())
