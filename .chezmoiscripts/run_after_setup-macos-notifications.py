#!/usr/bin/python3

import os
import platform
import plistlib
import subprocess
import sys
import time
from pathlib import Path


SILENT_BANNERS = {
    "allow": True, "style": "temporary", "center": True,
    "lock": True, "badge": False, "sound": False,
}
POLICY = {
    "com.apple.AppStore": {**SILENT_BANNERS, "style": "none", "badge": True},
    "com.apple.FaceTime": {"allow": False},
    "com.apple.Home": {"allow": False},
    "com.apple.Passbook": {"allow": False},
    "com.apple.Passwords": {
        "allow": True, "style": "temporary", "center": True,
        "lock": True, "sound": False,
    },
    "com.apple.Photos": {"allow": False},
    "com.apple.ScriptEditor2": SILENT_BANNERS,
    "com.apple.finder": SILENT_BANNERS,
    "com.apple.gamecenter": {"allow": False},
    "com.apple.mobilephone": {"allow": False},
    "com.apple.tips": {"allow": False},
    "com.google.Chrome": SILENT_BANNERS,
    "com.google.Chrome.framework.AlertNotificationService": SILENT_BANNERS,
    "com.google.chrome.for.testing": {"allow": False},
    "com.google.chrome.for.testing.framework.AlertNotificationService": {"allow": False},
    "com.openai.codex": {**SILENT_BANNERS, "badge": True, "sound": True},
    "com.superlogical.rex": {
        **SILENT_BANNERS, "style": "persistent", "lock": False, "grouping": 0,
    },
}

# usernoted stores preferences alongside registration state in a 64-bit flags word.
# Center and lock-screen bits are inverted; unowned bits must survive an apply.
BITS = {
    "allow": (1 << 25, False), "center": (1, True),
    "lock": (1 << 12, True), "badge": (2, False), "sound": (4, False),
}
STYLES = {"none": 0, "temporary": 8, "persistent": 16}
PENDING_RELOAD = Path.home() / "Library/Application Support/com.liby.macos-notifications/pending-reload"


def reconcile(preferences):
    apps = preferences["apps"]
    if not isinstance(apps, list):
        fail("Notification preferences 'apps' must be an array")
    changed, missing = set(), set(POLICY)
    for app in apps:
        bundle_id = app.get("bundle-id")
        if bundle_id not in POLICY:
            continue
        missing.discard(bundle_id)
        flags = app["flags"]
        if type(flags) is not int:
            fail(f"Invalid notification flags for {bundle_id}")
        settings = POLICY[bundle_id]
        for key, (bit, inverted) in BITS.items():
            if key in settings:
                flags = flags | bit if settings[key] != inverted else flags & ~bit
        if "style" in settings:
            flags = (flags & ~24) | STYLES[settings["style"]]
        if flags != app["flags"]:
            app["flags"] = flags
            changed.add(bundle_id)
        if "grouping" in settings and app.get("grouping") != settings["grouping"]:
            app["grouping"] = settings["grouping"]
            changed.add(bundle_id)
    return changed, missing


def style(text, sgr):
    return f"\033[{sgr}m{text}\033[0m" if sys.stderr.isatty() else text


def fail(message):
    raise SystemExit(f"{style('✗', 31)} {message}")


def terminal_app():
    # macOS checks Full Disk Access against the app bundle hosting the terminal. Start above
    # this interpreter, which /usr/bin/python3 runs from inside Xcode's or the Command Line
    # Tools' Python.app.
    pid = os.getppid()
    while pid > 1:
        result = subprocess.run(
            ["/bin/ps", "-o", "ppid=,comm=", "-p", str(pid)],
            stdout=subprocess.PIPE, text=True, timeout=15,
        )
        if result.returncode != 0:
            return None
        parent, command = result.stdout.strip().split(None, 1)
        if ".app/" in command:
            return command[:command.index(".app/") + len(".app")]
        pid = int(parent)
    return None


def request_full_disk_access():
    # macOS lists an app under Full Disk Access, switched off, after a denied read of Safari's data,
    # but not after one of usernoted's, so the user only has to turn it on.
    try:
        os.listdir(Path.home() / "Library/Safari")
    except OSError:
        pass
    subprocess.run(
        ["/usr/bin/open", "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"],
        timeout=15,
    )

    app = terminal_app()
    message = [
        f"{style('✗', 31)} macOS denied access to notification settings, which requires Full Disk Access.",
        f"  1. Turn on {style(Path(app).stem, 1) if app else 'the app hosting this terminal'} "
        "in System Settings > Privacy & Security > Full Disk Access.",
    ]
    if app:
        message += [
            f"     If it is not listed, click +, press {style('Shift-Command-G', 1)}, and paste:",
            f"     {style(app, 36)}",
        ]
    message.append(f"  2. Run {style('chezmoi apply', 36)} again.")
    return "\n".join(message)


def read_preferences(domain):
    result = subprocess.run(
        ["/usr/bin/defaults", "export", domain, "-"], check=True,
        stdout=subprocess.PIPE, timeout=15,
    )
    preferences = plistlib.loads(result.stdout)
    if "apps" in preferences:
        return preferences
    # defaults exports an empty domain both when privacy protection denies the read and when no
    # app has registered yet; only a direct read tells the denial apart.
    try:
        open(f"{domain}.plist", "rb").close()
    except FileNotFoundError:
        pass
    except PermissionError:
        raise SystemExit(request_full_disk_access())
    return {**preferences, "apps": []}


def usernoted_pids():
    result = subprocess.run(
        ["/usr/bin/pgrep", "-U", str(os.getuid()), "-x", "usernoted"],
        stdout=subprocess.PIPE, text=True, timeout=15,
    )
    if result.returncode == 1:
        return set()
    result.check_returncode()
    return {int(pid) for pid in result.stdout.split()}


def restart_usernoted():
    previous_pids = usernoted_pids()
    subprocess.run(["/usr/bin/killall", "usernoted"], check=True, timeout=15)
    deadline = time.monotonic() + 15
    while True:
        current_pids = usernoted_pids()
        if current_pids and current_pids.isdisjoint(previous_pids):
            return
        if time.monotonic() >= deadline:
            fail("usernoted did not restart within 15 seconds")
        time.sleep(0.1)


def main():
    version = platform.mac_ver()[0]
    if version.split(".")[0] not in {"26", "27"}:
        fail(f"macOS {version} is not validated for notification preferences; revalidate usernoted's flag layout against System Settings")
    domain = str(Path.home() / (
        "Library/Group Containers/group.com.apple.usernoted/Library/Preferences/"
        "group.com.apple.usernoted"
    ))
    preferences = read_preferences(domain)
    changed, missing = reconcile(preferences)
    if missing:
        print(f"{style('!', 33)} Launch these apps so they register for notifications, then rerun chezmoi apply: "
              + ", ".join(sorted(missing)), file=sys.stderr)
    if not changed and not PENDING_RELOAD.exists():
        return
    if changed:
        PENDING_RELOAD.parent.mkdir(parents=True, exist_ok=True)
        PENDING_RELOAD.touch()
        # Import merges top-level keys; supplying only apps leaves Focus/global preferences alone.
        subprocess.run(
            ["/usr/bin/defaults", "import", domain, "-"], check=True,
            input=plistlib.dumps({"apps": preferences["apps"]}), timeout=15,
        )
    restart_usernoted()
    remaining, absent = reconcile(read_preferences(domain))
    if remaining or absent - missing:
        fail("Notification settings did not persist after reloading usernoted")
    PENDING_RELOAD.unlink()
    print(f"{style('✓', 32)} Notification settings applied", file=sys.stderr)


if __name__ == "__main__":
    main()
