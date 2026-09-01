import importlib.util
import os
import subprocess
import sys
import tempfile
import unittest
from contextlib import ExitStack
from pathlib import Path
from unittest.mock import call, patch

SCRIPT = (
    Path(__file__).parents[2]
    / ".chezmoiscripts"
    / "run_once_before_05-setup-case-sensitive-volume.py"
)
sys.dont_write_bytecode = True
SPEC = importlib.util.spec_from_file_location("case_volume", SCRIPT)
case_volume = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(case_volume)


class FstabTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / "fstab"
        self.mount = Path(self.temp.name) / "Code"
        self.spec = "UUID=11111111-1111-1111-1111-111111111111"

    def tearDown(self):
        self.temp.cleanup()

    def state(self):
        return case_volume.fstab_state(self.path, self.spec, self.mount)

    def test_missing_and_current_exact_entry(self):
        self.assertEqual(self.state(), "missing")
        self.path.write_text(f"# keep\n{self.spec} {self.mount} apfs rw 0 2\n")
        before = self.path.read_bytes()
        self.assertEqual(self.state(), "present")
        self.assertEqual(self.path.read_bytes(), before)

    def test_conflicts(self):
        entries = [
            f"UUID=other {self.mount} apfs rw 0 2",
            f"{self.spec} /other apfs rw 0 2",
            "LABEL=Code /other apfs rw 0 2",
            f"{self.spec} {self.mount} apfs ro 0 2",
            f"{self.spec} {self.mount} apfs rw 0 2\n{self.spec} {self.mount} apfs rw 0 2",
        ]
        for entry in entries:
            with self.subTest(entry=entry):
                self.path.write_text(entry + "\n")
                self.assertEqual(self.state(), "conflict")

    def test_editor_appends_once_and_preserves_existing_bytes(self):
        self.path.write_bytes(b"# existing without newline")
        env = {
            "CHEZMOI_CODE_VOLUME_SPEC": self.spec,
            "CHEZMOI_CODE_VOLUME_MOUNT": str(self.mount),
        }
        with patch.dict(os.environ, env):
            case_volume.append_fstab(self.path)
            first = self.path.read_bytes()
            case_volume.append_fstab(self.path)
        self.assertEqual(self.path.read_bytes(), first)
        self.assertEqual(self.state(), "present")

    def test_vifs_editor_environment_dispatches_to_append(self):
        env = {
            **os.environ,
            "CHEZMOI_CODE_VOLUME_EDIT_FSTAB": "1",
            "CHEZMOI_CODE_VOLUME_SPEC": self.spec,
            "CHEZMOI_CODE_VOLUME_MOUNT": str(self.mount),
        }
        result = subprocess.run(
            ["/usr/bin/python3", str(SCRIPT), str(self.path)], env=env,
            capture_output=True, text=True
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.state(), "present")


class DiscoveryTest(unittest.TestCase):
    def test_finds_home_container_and_unique_code_volume(self):
        replies = [
            {"APFSContainerReference": "disk3"},
            {"Containers": [{"ContainerReference": "disk3", "Volumes": [
                {"Name": "Data", "DeviceIdentifier": "disk3s5"},
                {"Name": "Code", "DeviceIdentifier": "disk3s7"},
            ]}]},
        ]
        stat = subprocess.CompletedProcess([], 0, stdout="disk3s5\n")
        with patch.object(case_volume.subprocess, "run", return_value=stat) as run, \
                patch.object(case_volume, "plist", side_effect=replies) as plist:
            self.assertEqual(case_volume.find_volume(), ("disk3", "disk3s7"))
        run.assert_called_once_with(
            ["/usr/bin/stat", "-f", "%Sd", str(Path.home())],
            check=True, stdout=subprocess.PIPE, text=True
        )
        self.assertEqual(plist.call_args_list, [
            call("info", "-plist", "disk3s5"),
            call("apfs", "list", "-plist", "disk3"),
        ])

    def test_rejects_duplicate_code_volumes(self):
        replies = [
            {"APFSContainerReference": "disk3"},
            {"Containers": [{"ContainerReference": "disk3", "Volumes": [
                {"Name": "Code", "DeviceIdentifier": "disk3s7"},
                {"Name": "Code", "DeviceIdentifier": "disk3s8"},
            ]}]},
        ]
        stat = subprocess.CompletedProcess([], 0, stdout="disk3s5\n")
        with patch.object(case_volume.subprocess, "run", return_value=stat), \
                patch.object(case_volume, "plist", side_effect=replies):
            with self.assertRaises(SystemExit):
                case_volume.find_volume()


class ProvisionTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.mount = Path(self.temp.name) / "Code"
        self.fstab = Path(self.temp.name) / "fstab"
        self.mount.mkdir()
        self.constants = ExitStack()
        self.constants.enter_context(patch.object(case_volume, "MOUNT", self.mount))
        self.constants.enter_context(patch.object(case_volume, "FSTAB", self.fstab))

    def tearDown(self):
        self.constants.close()
        self.temp.cleanup()

    @staticmethod
    def info(mount):
        return {"VolumeUUID": "11111111-1111-1111-1111-111111111111",
                "MountPoint": mount}

    def test_fresh_create_installs_fstab_before_plain_mount(self):
        with ExitStack() as stack:
            find = stack.enter_context(patch.object(
                case_volume, "find_volume",
                side_effect=[("disk3", None), ("disk3", "disk3s7")]))
            stack.enter_context(patch.object(
                case_volume, "target_device", side_effect=[None, "disk3s7"]))
            stack.enter_context(patch.object(
                case_volume, "volume_info",
                side_effect=[self.info(None), self.info(str(self.mount))]))
            install = stack.enter_context(patch.object(case_volume, "install_fstab"))
            stack.enter_context(patch.object(case_volume, "verify_case_sensitive"))
            stack.enter_context(patch.object(case_volume, "print", create=True))
            run = stack.enter_context(patch.object(case_volume.subprocess, "run"))
            case_volume.main()

        self.assertEqual(find.call_count, 2)
        install.assert_called_once_with("UUID=11111111-1111-1111-1111-111111111111")
        self.assertEqual(run.call_args_list, [
            call([case_volume.SUDO, case_volume.DISKUTIL, "apfs", "addVolume",
                  "disk3", "Case-sensitive APFS", "Code", "-nomount"], check=True),
            call([case_volume.SUDO, case_volume.DISKUTIL, "mount", "disk3s7"],
                 check=True),
        ])

    def test_correct_existing_state_is_not_mutated(self):
        entry = (f"UUID=11111111-1111-1111-1111-111111111111 "
                 f"{self.mount} apfs rw 0 2\n")
        self.fstab.write_text(entry)
        with ExitStack() as stack:
            stack.enter_context(patch.object(
                case_volume, "find_volume", return_value=("disk3", "disk3s7")))
            stack.enter_context(patch.object(
                case_volume, "target_device", return_value="disk3s7"))
            stack.enter_context(patch.object(
                case_volume, "volume_info", return_value=self.info(str(self.mount))))
            stack.enter_context(patch.object(case_volume, "verify_case_sensitive"))
            stack.enter_context(patch.object(case_volume, "print", create=True))
            run = stack.enter_context(patch.object(case_volume.subprocess, "run"))
            case_volume.main()
        run.assert_not_called()
        self.assertEqual(self.fstab.read_text(), entry)

    def test_volume_mounted_elsewhere_fails_without_mutation(self):
        with ExitStack() as stack:
            stack.enter_context(patch.object(
                case_volume, "find_volume", return_value=("disk3", "disk3s7")))
            stack.enter_context(patch.object(case_volume, "target_device", return_value=None))
            stack.enter_context(patch.object(
                case_volume, "volume_info", return_value=self.info("/Volumes/Code")))
            run = stack.enter_context(patch.object(case_volume.subprocess, "run"))
            with self.assertRaisesRegex(SystemExit, "unmount it manually"):
                case_volume.main()
        run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
