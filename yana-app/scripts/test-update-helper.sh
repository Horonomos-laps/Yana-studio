#!/usr/bin/env bash
# Tries dmg/update.sh on made-up apps in a temporary folder, with a temporary home. Touches nothing installed.
set -u
here="$(cd "$(dirname "$0")/.." && pwd)"
helper="$here/dmg/update.sh"
work="$(mktemp -d "${TMPDIR:-/tmp}/yana-update-test.XXXXXX")"
pass=0
bad=0

make_app() { # path, identifier, version
	mkdir -p "$1/Contents/MacOS"
	cp /bin/sleep "$1/Contents/MacOS/YanaApp"
	cat >"$1/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>$2</string>
<key>CFBundleExecutable</key><string>YanaApp</string>
<key>CFBundleShortVersionString</key><string>$3</string>
</dict></plist>
EOF
	codesign --force --sign - "$1" >/dev/null 2>&1
}
version_of() { /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$1/Contents/Info.plist" 2>/dev/null; }
run() { HOME="$work/home" bash "$helper" "$@" >"$work/out" 2>&1; }
check() { # name, wanted, got
	if [[ "$2" == "$3" ]]; then pass=$((pass + 1)); echo "PASS $1"; else bad=$((bad + 1)); echo "FAIL $1: wanted $2, got $3 ($(tail -1 "$work/out"))"; fi
}

disk="$work/Yana 1.1.0 đĩa"
apps="$work/Applications có dấu"
mkdir -p "$disk" "$apps" "$work/home"
make_app "$disk/Yana.app" ai.yana.app 1.1.0
target="$apps/Yana.app"

run "$disk/Yana.app" "$target"; check "installs when nothing is there" "0 1.1.0" "$? $(version_of "$target")"
make_app "$target" ai.yana.app 1.0.0
run "$disk/Yana.app" "$target"; check "replaces the old version" "0 1.1.0" "$? $(version_of "$target")"
check "keeps the old one in the Trash" "1" "$(ls -d "$work/home/.Trash"/Yana-before-update-*.app 2>/dev/null | wc -l | tr -d ' ')"
check "leaves no half copy behind" "0" "$(ls -a "$apps" | grep -c Yana-new)"

for bad_args in "" "relative.app" ; do
	run "$bad_args" "$target"; check "refuses a bad new path '$bad_args'" "2" "$?"
done
run "$disk/Yana.app" "$apps"; check "refuses a target that is not an app path" "2" "$?"
run "$target" "$target"; check "refuses to replace an app with itself" "2" "$?"
make_app "$work/Other.app" com.example.other 9.9.9
run "$work/Other.app" "$target"; check "refuses a new app that is not Yana" "2 1.1.0" "$? $(version_of "$target")"
make_app "$apps/Mine.app" com.example.mine 3.0.0
run "$disk/Yana.app" "$apps/Mine.app"; check "never replaces another app" "2 3.0.0" "$? $(version_of "$apps/Mine.app")"
ln -s "$apps/Mine.app" "$apps/Link.app"
run "$disk/Yana.app" "$apps/Link.app"; check "refuses a link" "2" "$?"

make_app "$target" ai.yana.app 1.0.0
"$target/Contents/MacOS/YanaApp" 20 &
open_pid=$!
run "$disk/Yana.app" "$target"; check "waits when Yana is open" "3 1.0.0" "$? $(version_of "$target")"
kill "$open_pid" 2>/dev/null; wait "$open_pid" 2>/dev/null

make_app "$work/damaged/Yana.app" ai.yana.app 1.2.0
echo tampered >>"$work/damaged/Yana.app/Contents/Info.plist"
run "$work/damaged/Yana.app" "$target"; check "refuses a damaged copy and keeps the old app" "1.0.0" "$(version_of "$target")"

echo "update helper: $pass passed, $bad failed (files in $work)"
[[ $bad -eq 0 ]]
