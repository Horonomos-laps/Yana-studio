#!/bin/bash
# Replaces the installed Yana with the one on this disk image, for people coming from a version that cannot update
# itself. The old app goes to the Trash, nothing is erased, and settings, chats and keys live outside the app.
# Usage: update.sh <new Yana.app> <installed Yana.app>
# Exit: 0 done, 2 wrong input, 3 Yana or Yana Studio is still open, 4 could not copy or move.
set -u

new="${1:-}"
target="${2:-}"
bundle_id="ai.yana.app"

fail() { echo "$2" >&2; exit "$1"; }
id_of() { /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$1/Contents/Info.plist" 2>/dev/null; }

[[ "$new" == /*.app && "$target" == /*.app ]] || fail 2 "two full .app paths are needed"
[[ -d "$new" && "$(id_of "$new")" == "$bundle_id" ]] || fail 2 "the new app is not Yana"
if [[ -e "$target" || -L "$target" ]]; then
	[[ -d "$target" && ! -L "$target" && "$(id_of "$target")" == "$bundle_id" ]] || fail 2 "what is installed there is not Yana"
	[[ "$new" -ef "$target" ]] && fail 2 "the new app and the installed one are the same"
fi

# Nothing is closed by force: unsaved work in the app or in Studio stays the person's to finish.
if ps -axo command= | grep -F -- "$target/Contents/" | grep -v grep >/dev/null; then
	fail 3 "Yana or Yana Studio is still open"
fi

parent="$(dirname "$target")"
staged="$parent/.Yana-new-$$.app"
trash="$HOME/.Trash"
old="$trash/Yana-before-update-$(date +%Y%m%d-%H%M%S)-$$.app"

ditto "$new" "$staged" || fail 4 "could not copy the new app into $parent"
if ! codesign --verify --deep --strict "$staged" 2>/dev/null; then
	mv "$staged" "$trash/Yana-damaged-copy-$$.app" 2>/dev/null
	fail 4 "the copy does not pass its signature check"
fi
if [[ -e "$target" ]]; then
	mkdir -p "$trash" && mv "$target" "$old" || { mv "$staged" "$trash/Yana-unused-copy-$$.app" 2>/dev/null; fail 4 "could not move the old app to the Trash"; }
fi
if ! mv "$staged" "$target"; then
	[[ -e "$old" ]] && mv "$old" "$target"
	fail 4 "could not put the new app in place; the old one was put back"
fi
echo "updated"
