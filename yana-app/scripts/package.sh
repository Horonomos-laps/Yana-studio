#!/usr/bin/env bash
# Builds Yana.app from the SwiftPM target and packs it as Yana-<version>.dmg and .zip in dist/.
# Usage: scripts/package.sh [version]   (default: CFBundleShortVersionString in Info.plist)
# STUDIO_APP=/path/to/Yana\ Studio.app puts the Studio IDE inside as Contents/Applications/Yana Studio.app,
# where EditorLauncher looks first, so one download carries both apps.
# The app is signed ad-hoc only (no Developer ID): macOS shows an "unidentified developer" prompt on
# first open, and the AppUpdater picks up the .dmg/.zip assets of a GitHub release tagged app-v<version>.
set -euo pipefail
IFS=$'\n\t'

here="$(cd "$(dirname "$0")/.." && pwd)"
plist_buddy=/usr/libexec/PlistBuddy
base_version="$("$plist_buddy" -c 'Print :CFBundleShortVersionString' "$here/Info.plist")"
version="${1:-$base_version}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "version must look like 1.2.3, got: $version" >&2
	exit 2
fi

dist="$here/dist"
app="$dist/Yana.app"

# Turns a 1024 px PNG into an .icns with every size macOS asks for.
make_icns() {
	local png="$1" out="$2" set
	set="$(mktemp -d)/icon.iconset"
	mkdir -p "$set"
	for size in 16 32 128 256 512; do
		sips -z "$size" "$size" "$png" --out "$set/icon_${size}x${size}.png" >/dev/null
		sips -z "$((size * 2))" "$((size * 2))" "$png" --out "$set/icon_${size}x${size}@2x.png" >/dev/null
	done
	iconutil -c icns "$set" -o "$out"
}

cd "$here"
swift build -c release
bin_dir="$(swift build -c release --show-bin-path)"

mkdir -p "$dist"
if [[ -e "$app" ]]; then mv "$app" "$dist/.old-$(date +%s).app"; fi
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

cp "$bin_dir/YanaApp" "$app/Contents/MacOS/YanaApp"
# Sparkle, which updates the app in place, travels inside the bundle.
mkdir -p "$app/Contents/Frameworks"
ditto "$bin_dir/Sparkle.framework" "$app/Contents/Frameworks/Sparkle.framework"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$app/Contents/MacOS/YanaApp"
for bundle in "$bin_dir"/*.bundle; do cp -R "$bundle" "$app/Contents/Resources/"; done
# The third-party MediaRemote adapter (BSD-3, see Resources/MediaRemote/README.md): lets the notch read what any app plays.
cp -R "$(dirname "$0")/../Resources/MediaRemote" "$app/Contents/Resources/MediaRemote"
# Icons come from the in-app RabbitLogo (AppIconArt): light for Yana, dark with a code badge for Studio.
icon_dir="$(mktemp -d)"
"$bin_dir/YanaApp" --icon "$icon_dir/app.png" app >/dev/null
"$bin_dir/YanaApp" --icon "$icon_dir/studio.png" studio >/dev/null
make_icns "$icon_dir/app.png" "$app/Contents/Resources/Yana.icns"
make_icns "$icon_dir/studio.png" "$icon_dir/studio.icns"

cp "$here/Info.plist" "$app/Contents/Info.plist"
info="$app/Contents/Info.plist"
"$plist_buddy" -c "Set :CFBundleShortVersionString $version" "$info"
"$plist_buddy" -c "Set :CFBundleVersion $version" "$info"
"$plist_buddy" -c "Add :CFBundleExecutable string YanaApp" "$info"
"$plist_buddy" -c "Add :CFBundlePackageType string APPL" "$info"
"$plist_buddy" -c "Add :CFBundleIconFile string Yana" "$info"
"$plist_buddy" -c "Add :LSApplicationCategoryType string public.app-category.developer-tools" "$info"

# In-place updates: the public half of the release key (not secret; the private half stays in the releaser's Keychain,
# see scripts/appcast.sh). SPARKLE_PUBLIC_KEY="" builds an app that does not update itself in place.
SPARKLE_PUBLIC_KEY="${SPARKLE_PUBLIC_KEY-dpMzbW4MTKc33tpyzguqL8axdXv1PKv1pjzTMllbqDw=}"
if [[ -n "$SPARKLE_PUBLIC_KEY" ]]; then
	feed="${SPARKLE_FEED_URL:-https://github.com/Horonomos-laps/Yana-studio/releases/latest/download/appcast.xml}"
	"$plist_buddy" -c "Add :SUPublicEDKey string $SPARKLE_PUBLIC_KEY" "$info"
	"$plist_buddy" -c "Add :SUFeedURL string $feed" "$info"
	"$plist_buddy" -c "Add :SUEnableAutomaticChecks bool true" "$info"
else
	echo "note: SPARKLE_PUBLIC_KEY is empty, so this build cannot update itself in place" >&2
fi

studio="${STUDIO_APP:-}"
if [[ -n "$studio" ]]; then
	if [[ ! -f "$studio/Contents/Info.plist" || ! -d "$studio/Contents/MacOS" ]]; then
		echo "STUDIO_APP is not an app bundle: $studio" >&2
		exit 2
	fi
	mkdir -p "$app/Contents/Applications"
	nested="$app/Contents/Applications/Yana Studio.app"
	ditto "$studio" "$nested"
	studio_icon="$("$plist_buddy" -c 'Print :CFBundleIconFile' "$nested/Contents/Info.plist")"
	cp "$icon_dir/studio.icns" "$nested/Contents/Resources/${studio_icon%.icns}.icns"
	# One version for the whole download: the Studio inside carries Yana's number (Settings > About reads
	# yanaStudioVersion). product.json "version" stays the Code-OSS base: extensions check it for compatibility.
	plutil -replace yanaStudioVersion -string "$version" "$nested/Contents/Resources/app/product.json"
	"$plist_buddy" -c "Set :CFBundleShortVersionString $version" "$nested/Contents/Info.plist"
	# Inside out: the nested app is sealed first, then the outer seal covers it.
	codesign --force --deep --sign - "$app/Contents/Applications/Yana Studio.app"
fi

codesign --force --deep --sign - "$app/Contents/Frameworks/Sparkle.framework"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"

zip_out="$dist/Yana-$version.zip"
dmg_out="$dist/Yana-$version.dmg"
rm -f "$zip_out" "$dmg_out"
ditto -c -k --keepParent "$app" "$zip_out"
# SKIP_DMG=1 stops after the .zip (trial builds; the .dmg needs Finder to lay out its window).
if [[ -n "${SKIP_DMG:-}" ]]; then
	echo "built $zip_out"
	exit 0
fi

# The install window: DmgBackground (1x + 2x in one tiff) behind Yana.app on the left and the Applications
# link on the right. Finder writes the layout into the volume's .DS_Store, so the image is laid out on a
# writable copy, then compressed.
stage="$(mktemp -d)"
cp -R "$app" "$stage/"
ln -s /Applications "$stage/Applications"
# The install guide, shown as a picture in the window: a click on it opens it like any image. The name is plain
# ASCII on purpose, because Finder looks the item up by name below and accented names differ between Unicode forms.
guide_name="Huong dan - Read me first.png"
cp "$here/dmg/install-guide.png" "$stage/$guide_name"
# One button for people on a version that cannot update itself: it swaps the installed app for this one
# (dmg/update.sh; the old app goes to the Trash). Plain ASCII name, for the same reason as the guide.
updater_name="Cap nhat Yana.app"
osacompile -o "$stage/$updater_name" "$here/dmg/update.applescript"
cp "$here/dmg/update.sh" "$stage/$updater_name/Contents/Resources/update.sh"
codesign --force --sign - "$stage/$updater_name"
mkdir -p "$stage/.background"
"$bin_dir/YanaApp" --dmg-background "$icon_dir/bg@2x.png" >/dev/null
sips -z 460 640 "$icon_dir/bg@2x.png" --out "$icon_dir/bg.png" >/dev/null
tiffutil -cathidpicheck "$icon_dir/bg.png" "$icon_dir/bg@2x.png" -out "$stage/.background/background.tiff" >/dev/null

volname="Yana $version"
rw_dmg="$icon_dir/rw.dmg"
hdiutil create -quiet -volname "$volname" -srcfolder "$stage" -format UDRW -fs HFS+ "$rw_dmg"
mount_dir="/Volumes/$volname"
hdiutil attach -quiet -noautoopen "$rw_dmg"
osascript <<EOF
tell application "Finder"
	tell disk "$volname"
		open
		set current view of container window to icon view
		set toolbar visible of container window to false
		set statusbar visible of container window to false
		set bounds of container window to {200, 120, 840, 602}
		set opts to the icon view options of container window
		set arrangement of opts to not arranged
		set icon size of opts to 112
		set text size of opts to 13
		set background picture of opts to file ".background:background.tiff"
		set position of item "Yana.app" of container window to {160, 200}
		set position of item "Applications" of container window to {480, 200}
		set position of item "$guide_name" of container window to {230, 322}
		set position of item "$updater_name" of container window to {410, 322}
		close
		open
		update without registering applications
		delay 1
		close
	end tell
end tell
EOF
sync
hdiutil detach -quiet "$mount_dir"
hdiutil convert -quiet "$rw_dmg" -format UDZO -o "$dmg_out"
mv "$stage" "$dist/.stage-$(date +%s)"

shasum -a 256 "$zip_out" "$dmg_out"
echo "built $app ($version)"
