#!/bin/sh
set -eu

# renovate: datasource=github-releases depName=jdx/mr-boxington
mbx_version=v1.24.0
destination=$1
archive=mbx-aarch64-apple-darwin.tar.gz

if [ -x "$destination/mbx" ] && [ "$("$destination/mbx" --version)" = "mbx ${mbx_version#v}" ]; then
  exit 0
fi

install_tmp=$(mktemp -d)
trap 'rm -rf "$install_tmp"' EXIT
release="https://github.com/jdx/mr-boxington/releases/download/$mbx_version"
curl -fsSL "$release/$archive" -o "$install_tmp/$archive"
curl -fsSL "$release/SHA256SUMS" -o "$install_tmp/SHA256SUMS"
cd "$install_tmp"
grep "  $archive\$" SHA256SUMS | shasum -a 256 --check --strict -
tar -xzf "$archive"
mkdir -p "$destination"
install -m 755 mbx "$destination/mbx"
