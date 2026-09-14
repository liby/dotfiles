#!/bin/zsh
set -euo pipefail

[[ "$OSTYPE" == darwin* ]] || exit 0

# Apps are named by bundle id, which is also their defaults domain; LaunchServices resolves the
# installed path, so nothing here assumes /Applications. AppleScript's `path to application id`
# would launch a stopped app, so the lookup goes through NSWorkspace.
app_path() {
  osascript -l JavaScript -e "ObjC.import('AppKit'); \$.NSWorkspace.sharedWorkspace.URLForApplicationWithBundleIdentifier('$1').path.js"
}

# Adding an app System Events already lists leaves one entry, so this needs no existence check.
for id in com.hezongyidev.Bob com.runjuu.Input-Source-Pro com.mowglii.ItsycalApp com.raycast.macos com.nssurge.surge-mac com.zzd.Xnip; do
  osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$(app_path "$id")\", hidden:false}" >/dev/null
done

# Bob and Xnip are sandboxed. `defaults` reaches Bob's container through its bundle id once that
# container exists, and Xnip keeps its settings in its app group, which only a path reaches and
# which Xnip fills on first launch by migrating its container defaults. Start all three so a
# machine where they never ran has both stores before anything is written.
bob=com.hezongyidev.Bob
itsycal=com.mowglii.ItsycalApp
xnip=com.zzd.Xnip
bob_prefs="$HOME/Library/Containers/$bob/Data/Library/Preferences/$bob.plist"
xnip_prefs="$HOME/Library/Group Containers/ME7L72N3S3.group.$xnip/Library/Preferences/ME7L72N3S3.group.$xnip"
for id in $bob $itsycal $xnip; do
  open -b "$id"
done
waited=0
until [[ -f "$bob_prefs" && "$(defaults read "$xnip_prefs" kXnipDidUserDefaultsMigrateToAppGroups 2>/dev/null)" == 1 ]]; do
  if (( ++waited > 60 )); then
    print -u2 "Bob or Xnip did not create its settings, so nothing was written; rerun chezmoi apply"
    exit 1
  fi
  sleep 1
done

# The apps read these values at launch, so quit them before writing and start them again after.
for id in $bob $itsycal $xnip; do
  executable_dir="$(app_path "$id")/Contents/MacOS/"
  pkill -f "$executable_dir" || true
  while pgrep -qf "$executable_dir"; do sleep 0.2; done
done

# Menu bar style 1 is the outlined date (0 is solid). Highlighted days are a bitmask from
# Sunday = 1 to Saturday = 64, while WeekStartDOW counts Sunday = 0. ShowEventDays is the agenda
# popup index: 0 to 7 are that many days, 8 is 14 and 9 is 31. `GlobalShortcut` is unset because
# no shortcut is recorded.
defaults write $itsycal HighlightedDOWs -int 65
defaults write $itsycal MenuBarIconType -int 1
defaults write $itsycal ShowEventDays -int 3
defaults write $itsycal WeekStartDOW -int 1

# Option+Shift+I opens the input translate window; modifiers are Carbon flags. Services and their
# API keys stay in the app: they are secrets and live in the same domain.
defaults write $bob shortcut_key_inputTranslate \
  '<dict><key>doubledModifiers</key><false/><key>key</key><string>i</string><key>modifiers</key><integer>2560</integer></dict>'

# The shortcut is an NSKeyedArchiver MASShortcut with KeyCode 0 and ModifierFlags 524288,
# Option+A; to change it, record the new one in Xnip and export this value again with
# `plutil -extract kXnipStartCaptureMASShortcut raw -o - <plist> | base64 -d | xxd -p | tr -d '\n'`.
defaults write "$xnip_prefs" kXnipCaptureSaveImageType -string NSPNGFileType
defaults write "$xnip_prefs" kXnipStartCaptureMASShortcut -data \
  62706c6973743030d4010203040506070a582476657273696f6e592461726368697665725424746f7058246f626a6563747312000186a05f100f4e534b657965644172636869766572d1080954726f6f748001a30b0c1355246e756c6cd30d0e0f101112574b6579436f64655624636c6173735d4d6f646966696572466c616773100080021200080000d2141516175a24636c6173736e616d655824636c61737365735b4d415353686f7274637574a218195b4d415353686f7274637574584e534f626a65637408111a24293237494c5153575d646c738183858a8f9aa3afb2be0000000000000101000000000000001a000000000000000000000000000000c7

for id in $bob $itsycal $xnip; do
  open -b "$id"
done

# The save location is not managed: Xnip can only write to a folder picked in its own dialog,
# which stores a per-machine security-scoped bookmark next to the path.
if ! defaults read "$xnip_prefs" kXnipScreenshotSavePathBookmark >/dev/null 2>&1; then
  echo "Pick Xnip's screenshot save location in its preferences; it is the only setting not managed here."
fi
