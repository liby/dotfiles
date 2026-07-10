#!/usr/bin/env bash
# Shared utilities for review scripts. Source, don't execute.

is_secret_like_path() {
  local result=1
  # Case-insensitive match, bash+zsh portable: lowercase the input and match lowercase patterns.
  local lowered
  lowered=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
	case "$lowered" in
		.env.example|*/.env.example) result=1 ;;
		.env*|.env*/*|*/.env*|*/.env*/*) result=0 ;;
		*.pem|*.key|*.p12|*.pfx|*.crt|*.cer) result=0 ;;
		id_rsa|id_dsa|id_ecdsa|id_ed25519|*/id_rsa|*/id_dsa|*/id_ecdsa|*/id_ed25519) result=0 ;;
		authorized_keys|*/authorized_keys|known_hosts|*/known_hosts) result=0 ;;
		.ssh|*/.ssh|*/.ssh/*|.ssh/*|*.history|.*_history|*/.*_history|*.log|*.log/*|log|logs|*/log|*/logs|log/*|logs/*|*/log/*|*/logs/*) result=0 ;;
	esac
  return "$result"
}

# validate_path_file_nul <nul-delimited-file>
# Scans paths for secret-like names. Returns 4 on refusal.
validate_path_file_nul() {
  # "entry" not "path": zsh ties $path to $PATH, so `local path` would blank PATH in the function.
  local entry
  local refused=0
  while IFS= read -r -d '' entry; do
    [ -z "$entry" ] && continue
    is_secret_like_path "$entry" && refused=$((refused + 1))
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
  # "state" not "status" ($status is zsh's read-only $?); "entry" not "path" ($path is zsh's tied PATH array).
  local state entry extra
  : > "$output"
  while IFS= read -r -d '' state; do
    case "$state" in
      R*|C*)
        IFS= read -r -d '' entry || break
        IFS= read -r -d '' extra || break
        printf '%s\0%s\0' "$entry" "$extra" >> "$output"
        ;;
      *)
        IFS= read -r -d '' entry || break
        printf '%s\0' "$entry" >> "$output"
        ;;
    esac
  done < <(git diff -z --name-status "$from...$to" --)
}

# Convert a NUL-delimited path file to git literal pathspec format.
path_file_nul_to_literal_pathspec() {
  local input="$1" output="$2"
  local entry
  : > "$output"
  while IFS= read -r -d '' entry; do
    [ -z "$entry" ] && continue
    printf ':(literal)%s\0' "$entry" >> "$output"
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
