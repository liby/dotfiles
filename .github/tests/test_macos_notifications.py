import copy
import importlib.util
import io
import plistlib
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPT = Path(__file__).parents[2] / ".chezmoiscripts/run_after_setup-macos-notifications.py"
sys.dont_write_bytecode = True
SPEC = importlib.util.spec_from_file_location("macos_notifications", SCRIPT)
notifications = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(notifications)


class ReconcileTest(unittest.TestCase):
    def test_selected_fields_preserve_registration_and_other_apps(self):
        preferences = {"apps": [
            {"bundle-id": "target", "flags": (1 << 60) | 32 | 4096 | 7,
             "grouping": 2, "content_visibility": 3, "registration": b"opaque"},
            {"bundle-id": "unrelated", "flags": 123, "grouping": 1},
        ], "global": {"preserve": True}}
        original = copy.deepcopy(preferences)
        policy = {"target": {
            "allow": True, "center": True, "lock": True,
            "badge": False, "sound": False, "style": "persistent",
        }}
        with patch.object(notifications, "POLICY", policy):
            self.assertEqual(notifications.reconcile(preferences), ({"target"}, set()))
            self.assertEqual(preferences["apps"][0]["flags"], (1 << 60) | 32 | (1 << 25) | 16)
            expected = copy.deepcopy(original)
            expected["apps"][0]["flags"] = preferences["apps"][0]["flags"]
            self.assertEqual(preferences, expected)
            self.assertEqual(notifications.reconcile(preferences), (set(), set()))

    def test_disable_only_owns_allow_bit_in_every_matching_registration(self):
        preferences = {"apps": [
            {"bundle-id": "target", "flags": (1 << 25) | 4096 | 31},
            {"bundle-id": "target", "flags": (1 << 60) | (1 << 25) | 8},
        ]}
        with patch.object(notifications, "POLICY", {"target": {"allow": False}}):
            self.assertEqual(notifications.reconcile(preferences), ({"target"}, set()))
        self.assertEqual([a["flags"] for a in preferences["apps"]], [4096 | 31, (1 << 60) | 8])

    def test_styles_clear_both_old_style_bits_and_grouping_is_explicit(self):
        for style, expected in [("none", 0), ("temporary", 8), ("persistent", 16)]:
            with self.subTest(style=style):
                preferences = {"apps": [{"bundle-id": "target", "flags": 24, "grouping": 2}]}
                with patch.object(notifications, "POLICY", {"target": {"style": style, "grouping": 0}}):
                    notifications.reconcile(preferences)
                self.assertEqual(preferences["apps"][0], {
                    "bundle-id": "target", "flags": expected, "grouping": 0,
                })

    def test_missing_registration_is_reported_without_fabricating_state(self):
        preferences = {"apps": []}
        with patch.object(notifications, "POLICY", {"target": {"allow": True}}):
            self.assertEqual(notifications.reconcile(preferences), (set(), {"target"}))
        self.assertEqual(preferences, {"apps": []})


class ApplyTest(unittest.TestCase):
    def setUp(self):
        self.policy = patch.object(notifications, "POLICY", {"target": {"allow": True}})
        self.version = patch.object(notifications.platform, "mac_ver", return_value=("27.0.1", (), ""))
        self.policy.start()
        self.version.start()
        self.addCleanup(self.policy.stop)
        self.addCleanup(self.version.stop)
        temporary = tempfile.TemporaryDirectory(prefix="notifications-test-")
        self.addCleanup(temporary.cleanup)
        self.pending_reload = Path(temporary.name) / "state" / "pending-reload"
        home = patch.object(notifications.Path, "home", return_value=Path(temporary.name))
        home.start()
        self.addCleanup(home.stop)
        self.store = Path(temporary.name) / (
            "Library/Group Containers/group.com.apple.usernoted/Library/Preferences/group.com.apple.usernoted.plist"
        )
        pending = patch.object(notifications, "PENDING_RELOAD", self.pending_reload)
        pending.start()
        self.addCleanup(pending.stop)
        restart = patch.object(notifications, "restart_usernoted")
        self.restart = restart.start()
        self.addCleanup(restart.stop)

    def exported(self, flags):
        return subprocess.CompletedProcess([], 0, stdout=plistlib.dumps({
            "apps": [
                {"bundle-id": "target", "flags": flags, "registration": b"opaque"},
                {"bundle-id": "unrelated", "flags": 1 << 60, "registration": b"other-opaque"},
            ],
            "global": {"preserve": True},
        }))

    def test_no_drift_does_not_write_or_restart(self):
        with patch.object(notifications.subprocess, "run", return_value=self.exported(1 << 25)) as run:
            notifications.main()
        self.assertEqual(run.call_count, 1)
        self.assertEqual(run.call_args.args[0][1], "export")
        self.restart.assert_not_called()
        self.assertFalse(self.pending_reload.parent.exists())

    def test_write_imports_only_apps_and_verifies_after_restart(self):
        replies = [self.exported(0), subprocess.CompletedProcess([], 0), self.exported(1 << 25)]
        with patch.object(notifications.subprocess, "run", side_effect=replies) as run:
            notifications.main()
        calls = run.call_args_list
        self.assertEqual([c.args[0][1] for c in calls], ["export", "import", "export"])
        self.assertEqual(plistlib.loads(calls[1].kwargs["input"]), {
            "apps": [
                {"bundle-id": "target", "flags": 1 << 25, "registration": b"opaque"},
                {"bundle-id": "unrelated", "flags": 1 << 60, "registration": b"other-opaque"},
            ],
        })
        self.restart.assert_called_once_with()
        self.assertFalse(self.pending_reload.exists())

    def test_reverted_write_is_an_error(self):
        replies = [self.exported(0), subprocess.CompletedProcess([], 0), self.exported(0)]
        with patch.object(notifications.subprocess, "run", side_effect=replies):
            with self.assertRaisesRegex(SystemExit, "did not persist"):
                notifications.main()
        self.assertTrue(self.pending_reload.exists())

    def test_already_missing_registration_is_allowed_but_new_loss_is_an_error(self):
        policy = {"target": {"allow": True}, "late": {"allow": True}}
        for target_lost in (False, True):
            with self.subTest(target_lost=target_lost):
                readback = self.exported(1 << 25)
                if target_lost:
                    preferences = plistlib.loads(readback.stdout)
                    preferences["apps"] = [app for app in preferences["apps"] if app["bundle-id"] != "target"]
                    readback.stdout = plistlib.dumps(preferences)
                replies = [self.exported(0), subprocess.CompletedProcess([], 0), readback]
                with patch.object(notifications, "POLICY", policy):
                    with patch.object(notifications.subprocess, "run", side_effect=replies):
                        with patch("builtins.print") as output:
                            if target_lost:
                                with self.assertRaisesRegex(SystemExit, "did not persist"):
                                    notifications.main()
                            else:
                                notifications.main()
                self.assertTrue(any("late" in call.args[0] for call in output.call_args_list))
                self.assertEqual(self.pending_reload.exists(), target_lost)

    def test_failed_reload_is_retried_when_preferences_already_match(self):
        self.restart.side_effect = [subprocess.CalledProcessError(1, ["native-tool"]), None]
        replies = [self.exported(0), subprocess.CompletedProcess([], 0)]
        with patch.object(notifications.subprocess, "run", side_effect=replies):
            with self.assertRaises(subprocess.CalledProcessError):
                notifications.main()
        self.assertTrue(self.pending_reload.exists())
        with patch.object(notifications.subprocess, "run", return_value=self.exported(1 << 25)) as run:
            notifications.main()
        self.assertEqual(self.restart.call_count, 2)
        self.assertEqual([c.args[0][1] for c in run.call_args_list], ["export", "export"])
        self.assertFalse(self.pending_reload.exists())

    def test_export_and_import_failures_propagate(self):
        for failed_call in range(2):
            with self.subTest(failed_call=failed_call):
                replies = [self.exported(0)][:failed_call] + [subprocess.CalledProcessError(1, ["native-tool"])]
                with patch.object(notifications.subprocess, "run", side_effect=replies) as run:
                    with self.assertRaises(subprocess.CalledProcessError):
                        notifications.main()
                self.assertEqual(run.call_count, failed_call + 1)
                self.assertTrue(run.call_args.kwargs["check"])
                self.assertEqual(self.pending_reload.exists(), failed_call == 1)
        self.restart.assert_not_called()

    def test_malformed_store_and_unsupported_version_do_not_write(self):
        for preferences, error, message in [
            ({"apps": {}}, SystemExit, "must be an array"),
            ({"apps": [{"bundle-id": "target", "flags": True}]}, SystemExit, "Invalid notification flags"),
        ]:
            with self.subTest(preferences=preferences):
                reply = subprocess.CompletedProcess([], 0, stdout=plistlib.dumps(preferences))
                with patch.object(notifications.subprocess, "run", return_value=reply) as run:
                    with self.assertRaisesRegex(error, message):
                        notifications.main()
                self.assertEqual(run.call_count, 1)
        with patch.object(notifications.platform, "mac_ver", return_value=("99.0", (), "")):
            with patch.object(notifications.subprocess, "run") as run:
                with self.assertRaisesRegex(SystemExit, "revalidate"):
                    notifications.main()
            run.assert_not_called()

    def test_empty_export_denied_by_privacy_names_the_terminal_app_to_authorize(self):
        reply = subprocess.CompletedProcess([], 0, stdout=plistlib.dumps({}))
        rex_server = "/Users/me/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app"
        self.store.parent.mkdir(parents=True)
        self.store.touch(mode=0)
        for app, tty in ((rex_server, False), (None, False), (rex_server, True)):
            with self.subTest(app=app, tty=tty):
                stderr = io.StringIO()
                stderr.isatty = lambda: tty
                with patch.object(notifications.sys, "stderr", stderr):
                    with patch.object(notifications, "terminal_app", return_value=app):
                        with patch.object(notifications.os, "listdir", side_effect=PermissionError) as listdir:
                            with patch.object(notifications.subprocess, "run", return_value=reply) as run:
                                with self.assertRaises(SystemExit) as raised:
                                    notifications.main()
                message = str(raised.exception.code)
                self.assertEqual("\033[" in message, tty)
                if app:
                    self.assertIn(app, message)
                else:
                    self.assertNotIn("Shift-Command-G", message)
                listdir.assert_called_once_with(Path.home() / "Library/Safari")
                self.assertEqual([c.args[0][0] for c in run.call_args_list], ["/usr/bin/defaults", "/usr/bin/open"])
                self.assertIn("Privacy_AllFiles", run.call_args.args[0][1])

    def test_empty_export_without_denial_reports_unregistered_apps_and_succeeds(self):
        reply = subprocess.CompletedProcess([], 0, stdout=plistlib.dumps({}))
        for readable in (False, True):
            with self.subTest(readable=readable):
                if readable:
                    self.store.parent.mkdir(parents=True)
                    self.store.touch()
                with patch.object(notifications.subprocess, "run", return_value=reply) as run:
                    with patch("builtins.print") as output:
                        notifications.main()
                self.assertIn("target", output.call_args.args[0])
                self.assertEqual(run.call_count, 1)
                self.restart.assert_not_called()


class TerminalAppTest(unittest.TestCase):
    def test_returns_outermost_bundle_of_nearest_app_ancestor(self):
        rex_server = "/Users/me/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app"
        for ancestors, expected in [
            (["20 /opt/homebrew/bin/chezmoi", "10 /usr/bin/login", f"1 {rex_server}/Contents/MacOS/rex"], rex_server),
            (["1 /Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper (Plugin).app/Contents/MacOS/Code Helper (Plugin)"],
             "/Applications/Visual Studio Code.app"),
            (["1 /usr/sbin/sshd"], None),
            ([None], None),
        ]:
            with self.subTest(ancestors=ancestors):
                replies = [
                    subprocess.CompletedProcess([], 1, stdout="") if line is None
                    else subprocess.CompletedProcess([], 0, stdout=f"  {line}\n")
                    for line in ancestors
                ]
                with patch.object(notifications.os, "getppid", return_value=30):
                    with patch.object(notifications.subprocess, "run", side_effect=replies) as run:
                        self.assertEqual(notifications.terminal_app(), expected)
                self.assertEqual(run.call_args_list[0].args[0][-1], "30")
                self.assertEqual(run.call_count, len(ancestors))


class RestartTest(unittest.TestCase):
    def test_waits_for_all_old_pids_to_exit_and_new_pids_to_start(self):
        replies = [{10, 11}, {10, 12}, set(), {12, 13}]
        with patch.object(notifications, "usernoted_pids", side_effect=replies) as pids:
            with patch.object(notifications.subprocess, "run") as run:
                with patch.object(notifications.time, "sleep") as sleep:
                    notifications.restart_usernoted()
        run.assert_called_once_with(["/usr/bin/killall", "usernoted"], check=True, timeout=15)
        self.assertEqual(pids.call_count, 4)
        self.assertEqual(sleep.call_count, 2)

    def test_signal_failure_and_restart_timeout_propagate(self):
        with patch.object(notifications, "usernoted_pids", return_value={10}):
            with patch.object(notifications.subprocess, "run", side_effect=subprocess.CalledProcessError(1, ["killall"])):
                with self.assertRaises(subprocess.CalledProcessError):
                    notifications.restart_usernoted()
            with patch.object(notifications.subprocess, "run"):
                with patch.object(notifications.time, "monotonic", side_effect=[0, 15]):
                    with self.assertRaisesRegex(SystemExit, "did not restart"):
                        notifications.restart_usernoted()

    def test_pgrep_scopes_real_uid_and_distinguishes_absence_from_error(self):
        for status in range(4):
            with self.subTest(status=status):
                result = subprocess.CompletedProcess([], status, stdout="10\n11\n" if status == 0 else "")
                with patch.object(notifications.subprocess, "run", return_value=result) as run:
                    if status < 2:
                        self.assertEqual(notifications.usernoted_pids(), {10, 11} if status == 0 else set())
                    else:
                        with self.assertRaises(subprocess.CalledProcessError):
                            notifications.usernoted_pids()
                self.assertEqual(run.call_args.args[0], [
                    "/usr/bin/pgrep", "-U", str(notifications.os.getuid()), "-x", "usernoted",
                ])


if __name__ == "__main__":
    unittest.main()
