#!/usr/bin/env bash
# Shared utilities for review scripts. Source, don't execute.

is_secret_like_path() {
  local result=1
  local restore_nocasematch=0
  shopt -q nocasematch || restore_nocasematch=1
  shopt -s nocasematch
	case "$1" in
		.env*|.env*/*|*/.env*|*/.env*/*) result=0 ;;
		*.pem|*.key|*.p12|*.pfx|*.crt|*.cer) result=0 ;;
		id_rsa|id_dsa|id_ecdsa|id_ed25519|*/id_rsa|*/id_dsa|*/id_ecdsa|*/id_ed25519) result=0 ;;
		authorized_keys|*/authorized_keys|known_hosts|*/known_hosts) result=0 ;;
		.ssh|*/.ssh|*/.ssh/*|.ssh/*|*.history|.*_history|*/.*_history|*.log|*.log/*|log|logs|*/log|*/logs|log/*|logs/*|*/log/*|*/logs/*) result=0 ;;
	esac
  [ "$restore_nocasematch" -eq 1 ] && shopt -u nocasematch
  return "$result"
}

# validate_path_file_nul <nul-delimited-file>
# Scans paths for secret-like names. Returns 4 on refusal.
validate_path_file_nul() {
  local path
  local refused=0
  while IFS= read -r -d '' path; do
    [ -z "$path" ] && continue
    is_secret_like_path "$path" && refused=$((refused + 1))
  done < "$1"
  if [ "$refused" -gt 0 ]; then
    echo "${0##*/}: refusing $refused secret-like path(s)" >&2
    echo "${0##*/}: inspect paths and rerun with only safe paths in scope" >&2
    return 4
  fi
  return 0
}

# Parse git diff -z --name-status output, writing paths (NUL-delimited) to a file.
git_diff_paths_nul() {
  local from="$1" to="$2" output="$3"
  local status path extra
  : > "$output"
  while IFS= read -r -d '' status; do
    case "$status" in
      R*|C*)
        IFS= read -r -d '' path || break
        IFS= read -r -d '' extra || break
        printf '%s\0%s\0' "$path" "$extra" >> "$output"
        ;;
      *)
        IFS= read -r -d '' path || break
        printf '%s\0' "$path" >> "$output"
        ;;
    esac
  done < <(git diff -z --name-status "$from...$to" --)
}

# Convert a NUL-delimited path file to git literal pathspec format.
path_file_nul_to_literal_pathspec() {
  local input="$1" output="$2"
  local path
  : > "$output"
  while IFS= read -r -d '' path; do
    [ -z "$path" ] && continue
    printf ':(literal)%s\0' "$path" >> "$output"
  done < "$input"
}

# Validate diff paths between two refs, exit 4 on secret-like paths.
validate_git_diff_paths() {
  local tmp_paths
  tmp_paths=$(mktemp)
  git_diff_paths_nul "$1" "$2" "$tmp_paths"
  validate_path_file_nul "$tmp_paths" || { rm "$tmp_paths"; exit 4; }
  rm "$tmp_paths"
}
