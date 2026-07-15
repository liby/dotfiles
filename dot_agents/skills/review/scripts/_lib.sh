#!/usr/bin/env bash
# Shared utilities for review scripts. Source, don't execute.

# validate_path_file_nul <nul-delimited-file>
# Refuses raw-secret names, stops on ambiguous sensitive names, and reports
# ciphertext candidates. Returns 4 for raw secrets and 5 for
# ambiguity that requires external classification.
validate_path_file_nul() {
  # "entry" not "path": zsh ties $path to $PATH, so `local path` would blank PATH in the function.
  local entry
  local refused=0
  local ciphertext_candidates=0
  local ambiguous=0
  while IFS= read -r -d '' entry; do
    [ -z "$entry" ] && continue
    case "$entry" in
      .env.example|*/.env.example) ;;
      .env.age|*/.env.age|.env.gpg|*/.env.gpg|.env.asc|*/.env.asc) ciphertext_candidates=$((ciphertext_candidates + 1)) ;;
      encrypted_*.asc|*/encrypted_*.asc) ciphertext_candidates=$((ciphertext_candidates + 1)) ;;
      .secrets/*.age|*/.secrets/*.age|.secrets/*.gpg|*/.secrets/*.gpg|.secrets/*.asc|*/.secrets/*.asc) ciphertext_candidates=$((ciphertext_candidates + 1)) ;;
      .env*|.env*/*|*/.env*|*/.env*/*) refused=$((refused + 1)) ;;
      .secrets|.secrets/*|*/.secrets|*/.secrets/*) refused=$((refused + 1)) ;;
      *.key|*.p12|*.pfx) refused=$((refused + 1)) ;;
      *.pem) ambiguous=$((ambiguous + 1)) ;;
      .ssh/config|*/.ssh/config|authorized_keys|*/authorized_keys|known_hosts|*/known_hosts|*.pub) ;;
      id_rsa|id_dsa|id_ecdsa|id_ed25519|*/id_rsa|*/id_dsa|*/id_ecdsa|*/id_ed25519) refused=$((refused + 1)) ;;
      .ssh|*/.ssh|*/.ssh/*|.ssh/*) ambiguous=$((ambiguous + 1)) ;;
      *.history|.*_history|*/.*_history|*.log|*.log/*|log|logs|*/log|*/logs|log/*|logs/*|*/log/*|*/logs/*) refused=$((refused + 1)) ;;
    esac
  done < <(LC_ALL=C tr '[:upper:]' '[:lower:]' < "$1")
  if [ "$ciphertext_candidates" -gt 0 ]; then
    echo "${0##*/}: found $ciphertext_candidates ciphertext candidate path(s)" >&2
    echo "${0##*/}: confirm encryption before reading any body; confirmed ciphertext stays opaque" >&2
  fi
  if [ "$refused" -gt 0 ]; then
    echo "${0##*/}: refusing $refused raw-secret path(s)" >&2
    echo "${0##*/}: remove raw-secret bodies from scope and rerun" >&2
    return 4
  fi
  if [ "$ambiguous" -gt 0 ]; then
    echo "${0##*/}: found $ambiguous ambiguous sensitive path(s)" >&2
    echo "${0##*/}: classify them without reading bodies, then rerun with only confirmed-safe paths" >&2
    return 5
  fi
  return 0
}

# Validate diff paths between two refs; propagates 4 (refusal) and 5 (ambiguous).
validate_git_diff_paths() (
  set -o pipefail
  git diff --no-renames --name-only -z "$1...$2" -- |
    validate_path_file_nul /dev/stdin
)

# Validate staged, unstaged, and untracked paths; propagates 4 (refusal) and 5 (ambiguous).
validate_working_tree_paths() (
  set -o pipefail
  {
    git diff --no-renames --name-only -z HEAD -- &&
      git ls-files -z --others --exclude-standard
  } | validate_path_file_nul /dev/stdin
)
