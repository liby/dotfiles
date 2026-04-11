#!/bin/zsh
set -euo pipefail

[[ "$OSTYPE" == darwin* ]] || exit 0

container_id=$(diskutil list | grep "APFS Container Scheme" | head -1 | awk '{print $NF}')
if [[ -z "$container_id" ]]; then
  echo "Error: No APFS container found"
  exit 1
fi

mkdir -p "$HOME/Code"

if ! diskutil apfs list | grep -q "Name:.*Code.*Case-sensitive"; then
  echo "Creating case-sensitive Code volume..."
  sudo diskutil apfs addVolume "$container_id" APFSX "Code"
fi

volume_id=$(diskutil apfs list | grep -B 3 "Name:.*Code.*Case-sensitive" | grep "Volume disk" | awk '{print $3}')
if [[ -z "$volume_id" ]]; then
  echo "Error: Code volume ID not found"
  exit 1
fi

current_mount=$(mount | grep "$volume_id" | awk '{print $3}')
if [[ -n "$current_mount" && "$current_mount" != "$HOME/Code" ]]; then
  echo "Volume mounted at $current_mount, remounting to $HOME/Code..."
  sudo diskutil unmount "$volume_id" || sudo diskutil unmount force "$volume_id"
fi

if ! mount | grep -q " $HOME/Code "; then
  sudo diskutil mount -mountPoint "$HOME/Code" "$volume_id"
fi

# Verify case sensitivity via inode comparison
(
  cd "$HOME/Code"
  ts=$(date +%s)
  touch "test_cs_$ts"
  inode1=$(stat -f %i "test_cs_$ts")
  inode2=$(stat -f %i "TEST_CS_$ts" 2>/dev/null || echo 0)
  rm -f "test_cs_$ts" "TEST_CS_$ts"
  if [[ "$inode1" == "$inode2" ]]; then
    echo "Error: volume is not case-sensitive"
    exit 1
  fi
)
