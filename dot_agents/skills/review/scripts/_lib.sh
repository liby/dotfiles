#!/usr/bin/env bash
# Shared utilities for review scripts. Source, don't execute.

# validate_path_file_nul <nul-delimited-file> [classified-ordinary-file]
# Both files contain NUL-delimited paths. The optional file records ordinary
# classifications established from non-value evidence, not permission overrides.
# Returns 2 for invalid input, 4 for declared env inputs, and 5 for unresolved hints.
validate_path_file_nul() {
  if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "${0##*/}: usage: validate_path_file_nul <path-list> [classified-ordinary-list]" >&2
    return 2
  fi
  local input_file="$1" ordinary_file="${2:-}" list_file
  for list_file in "$input_file" "$ordinary_file"; do
    [ -z "$list_file" ] && continue
    if [ ! -r "$list_file" ] || [ -d "$list_file" ]; then
      echo "${0##*/}: cannot read path list: $list_file" >&2
      return 2
    fi
  done
  # "entry" not "path": zsh ties $path to $PATH, so `local path` would blank PATH in the function.
  local entry normalized category ordinary_entry
  local refused=0
  local ciphertext_candidates=0
  local ambiguous=0
  # Git's pathspec-file-nul consumer also accepts a final path terminated by EOF.
  while IFS= read -r -d '' entry || [ -n "$entry" ]; do
    [ -z "$entry" ] && continue
    case "$entry" in
      *[ABCDEFGHIJKLMNOPQRSTUVWXYZ]*) normalized=$(printf '%s' "$entry" | LC_ALL=C tr '[:upper:]' '[:lower:]') || return $? ;;
      *) normalized=$entry ;;
    esac
    category=ordinary
    case "$normalized" in
      .env.age|*/.env.age|.env.gpg|*/.env.gpg|.env.asc|*/.env.asc) category=ciphertext-candidate ;;
      encrypted_*.asc|*/encrypted_*.asc) category=ciphertext-candidate ;;
      .secrets/*.age|*/.secrets/*.age|.secrets/*.gpg|*/.secrets/*.gpg|.secrets/*.asc|*/.secrets/*.asc) category=ciphertext-candidate ;;
      # The workspace env files Protected Inputs declares.
      .env|*/.env|.env.local|*/.env.local) category=protected ;;
      .secrets|.secrets/*|*/.secrets|*/.secrets/*) category=ambiguous ;;
      *.key|*.p12|*.pfx) category=ambiguous ;;
      id_rsa|id_dsa|id_ecdsa|id_ed25519|*/id_rsa|*/id_dsa|*/id_ecdsa|*/id_ed25519) category=ambiguous ;;
      *.history|.*_history|*/.*_history) category=ambiguous ;;
      # Case patterns let * cross "/", so .env* directories must match before the name rules below;
      # declared inputs above must stay ahead of this ambiguous branch.
      .env*/*|*/.env*/*) category=ambiguous ;;
      .env*.example|*/.env*.example|.env*.sample|*/.env*.sample|.env*.template|*/.env*.template) ;;
      .env*|*/.env*) category=ambiguous ;;
      *.pem) category=ambiguous ;;
      .ssh/config|*/.ssh/config|authorized_keys|*/authorized_keys|known_hosts|*/known_hosts|*.pub) ;;
      .ssh|*/.ssh|*/.ssh/*|.ssh/*) category=ambiguous ;;
    esac
    if [ "$category" = ambiguous ] && [ -n "$ordinary_file" ]; then
      while IFS= read -r -d '' ordinary_entry || [ -n "$ordinary_entry" ]; do
        if [ "$ordinary_entry" = "$entry" ]; then
          category=ordinary
          break
        fi
      done < "$ordinary_file" || return $?
    fi
    case "$category" in
      ciphertext-candidate) ciphertext_candidates=$((ciphertext_candidates + 1)) ;;
      protected) refused=$((refused + 1)) ;;
      ambiguous) ambiguous=$((ambiguous + 1)) ;;
    esac
    if [ "$category" != ordinary ]; then
      printf '%s: %s %q\n' "${0##*/}" "$category" "$entry" >&2
    fi
  done < "$input_file" || return $?
  if [ "$ciphertext_candidates" -gt 0 ]; then
    echo "${0##*/}: found $ciphertext_candidates ciphertext candidate path(s)" >&2
    echo "${0##*/}: confirm encryption before reading any body; confirmed ciphertext stays opaque" >&2
  fi
  if [ "$refused" -gt 0 ]; then
    echo "${0##*/}: refusing $refused protected input path(s); keep their bodies out of every diff" >&2
    return 4
  fi
  if [ "$ambiguous" -gt 0 ]; then
    echo "${0##*/}: found $ambiguous ambiguous sensitive path(s)" >&2
    echo "${0##*/}: classify without reading bodies; supply ordinary classifications only with host, project, or user evidence" >&2
    return 5
  fi
  return 0
}

# Validate diff paths between two refs, with an optional classified-ordinary file.
validate_git_diff_paths() (
  set -o pipefail
  git diff --no-renames --name-only -z "$1...$2" -- |
    validate_path_file_nul /dev/stdin "${3:-}"
)

# Validate staged, unstaged, and untracked paths, with an optional classified-ordinary file.
validate_working_tree_paths() (
  set -o pipefail
  local review_root
  review_root=$(git rev-parse --show-toplevel) || return $?
  {
    git -C "$review_root" diff --no-renames --name-only -z HEAD -- &&
      git -C "$review_root" ls-files -z --others --exclude-standard
  } | validate_path_file_nul /dev/stdin "${1:-}"
)
