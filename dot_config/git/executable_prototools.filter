#!/bin/sh
sed -E \
  -e 's/^(node) = "[0-9][^"]*"/\1 = "lts"/' \
  -e 's/^(bun|pnpm) = "[0-9][^"]*"/\1 = "latest"/' \
  -e 's/^(npm) = "[0-9][^"]*"/\1 = "bundled"/' \
  -e '/^(deno|go|proto|yarn) = "[0-9]/d'
