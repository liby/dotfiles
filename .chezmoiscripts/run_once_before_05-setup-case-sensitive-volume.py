#!/usr/bin/python3

import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

DISKUTIL, SUDO, VIFS = "/usr/sbin/diskutil", "/usr/bin/sudo", "/usr/sbin/vifs"
NAME = "Code"
MOUNT, FSTAB = Path.home() / NAME, Path("/etc/fstab")


def fail(message):
    raise SystemExit(f"setup-case-sensitive-volume: {message}")


def plist(*args):
    result = subprocess.run([DISKUTIL, *args], check=True, stdout=subprocess.PIPE)
    return plistlib.loads(result.stdout)


def find_volume():
    home_device = subprocess.run(
        ["/usr/bin/stat", "-f", "%Sd", str(Path.home())],
        check=True, stdout=subprocess.PIPE, text=True
    ).stdout.strip()
    container = plist("info", "-plist", home_device)["APFSContainerReference"]
    containers = plist("apfs", "list", "-plist", container)["Containers"]
    if len(containers) != 1 or containers[0]["ContainerReference"] != container:
        fail(f"could not isolate HOME container {container}")
    matches = [v for v in containers[0]["Volumes"] if v.get("Name") == NAME]
    if len(matches) > 1:
        fail(f"multiple {NAME} volumes exist in {container}")
    return container, matches[0]["DeviceIdentifier"] if matches else None


def volume_info(device, container):
    info = plist("info", "-plist", device)
    expected = (device, NAME, container, "Case-sensitive APFS")
    actual = tuple(info.get(key) for key in (
        "DeviceIdentifier", "VolumeName", "APFSContainerReference", "FilesystemName"
    ))
    if actual != expected:
        fail(f"{device} is not the case-sensitive {NAME} volume in {container}")
    return info


def fstab_state(path, spec, mount=None, name=NAME):
    mount = mount or MOUNT
    if not path.exists():
        return "missing"
    relevant = []
    for line in path.read_text().splitlines():
        fields = line.partition("#")[0].split()
        if len(fields) >= 2 and (
            fields[0] == f"LABEL={name}" or fields[1] == str(mount)
            or (spec and fields[0] == spec)
        ):
            relevant.append(fields)
    if not relevant:
        return "missing"
    expected = [spec, str(mount), "apfs", "rw", "0", "2"]
    return "present" if spec and relevant == [expected] else "conflict"


def append_fstab(path):
    spec = os.environ["CHEZMOI_CODE_VOLUME_SPEC"]
    mount = Path(os.environ["CHEZMOI_CODE_VOLUME_MOUNT"])
    state = fstab_state(path, spec, mount)
    if state == "present":
        return
    if state == "conflict":
        fail("fstab changed while it was being edited")
    with path.open("ab+") as output:
        output.seek(0, os.SEEK_END)
        if output.tell():
            output.seek(-1, os.SEEK_END)
            if output.read(1) != b"\n":
                output.write(b"\n")
        output.write(f"{spec} {mount} apfs rw 0 2\n".encode())


def install_fstab(spec):
    env = [
        f"EDITOR={Path(sys.argv[0]).resolve()}",
        "CHEZMOI_CODE_VOLUME_EDIT_FSTAB=1",
        f"CHEZMOI_CODE_VOLUME_SPEC={spec}",
        f"CHEZMOI_CODE_VOLUME_MOUNT={MOUNT}",
    ]
    subprocess.run([SUDO, "/usr/bin/env", *env, VIFS], check=True)
    if fstab_state(FSTAB, spec) != "present":
        fail("failed to install the fstab entry")


def target_device():
    if not MOUNT.exists() or not MOUNT.is_mount():
        return None
    try:
        return plist("info", "-plist", str(MOUNT))["DeviceIdentifier"]
    except (KeyError, plistlib.InvalidFileException, subprocess.CalledProcessError):
        fail(f"{MOUNT} is occupied by an unrecognized filesystem")


def require_empty_directory():
    if not MOUNT.exists():
        return
    try:
        nonempty = next(MOUNT.iterdir(), None) is not None
    except OSError as error:
        fail(f"cannot inspect {MOUNT}: {error}")
    if nonempty:
        fail(f"{MOUNT} must be empty")


def verify_case_sensitive():
    probe = Path(tempfile.mkdtemp(prefix=".chezmoi-case-", dir=MOUNT))
    try:
        (probe / "lower").touch()
        if (probe / "LOWER").exists():
            fail(f"{MOUNT} is not case-sensitive")
    finally:
        shutil.rmtree(probe)


def main():
    if MOUNT.is_symlink() or (MOUNT.exists() and not MOUNT.is_dir()):
        fail(f"{MOUNT} must be a directory, not a symlink or file")

    container, device = find_volume()
    mounted_at_target = target_device()
    if device is None:
        if fstab_state(FSTAB, None) != "missing":
            fail(f"fstab already refers to LABEL={NAME} or {MOUNT}")
        if mounted_at_target:
            fail(f"{MOUNT} is already a mount point")
        require_empty_directory()
        MOUNT.mkdir(parents=True, exist_ok=True)
        subprocess.run([
            SUDO, DISKUTIL, "apfs", "addVolume", container,
            "Case-sensitive APFS", NAME, "-nomount"
        ], check=True)
        _, device = find_volume()
        if device is None:
            fail(f"created {NAME} volume could not be found")

    info = volume_info(device, container)
    current_mount = info.get("MountPoint") or None
    if current_mount and current_mount != str(MOUNT):
        fail(f"{device} is mounted at {current_mount}; unmount it manually")
    if mounted_at_target and mounted_at_target != device:
        fail(f"{MOUNT} is mounted from {mounted_at_target}, not {device}")
    if not current_mount:
        require_empty_directory()
        MOUNT.mkdir(parents=True, exist_ok=True)

    spec = f"UUID={info['VolumeUUID']}"
    state = fstab_state(FSTAB, spec)
    if state == "conflict":
        fail(f"conflicting fstab entry for {spec} or {MOUNT}")
    if state == "missing":
        install_fstab(spec)
    if not current_mount:
        subprocess.run([SUDO, DISKUTIL, "mount", device], check=True)

    final = volume_info(device, container)
    if final.get("MountPoint") != str(MOUNT) or target_device() != device:
        fail(f"{device} did not mount at {MOUNT}")
    verify_case_sensitive()
    print(f"Case-sensitive {NAME} volume ready at {MOUNT}.")


if __name__ == "__main__":
    if os.environ.get("CHEZMOI_CODE_VOLUME_EDIT_FSTAB"):
        if len(sys.argv) != 2:
            fail("vifs did not provide exactly one fstab path")
        append_fstab(Path(sys.argv[1]))
    else:
        main()
