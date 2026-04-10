#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME=$(basename "$0")
ROOT=""
ARTIFACT_ROOT="${CODEX_ARTIFACT_ROOT:-codex-artifacts}"
STAGE_ARTIFACTS=0

usage() {
  cat << USAGE
Usage:
  $SCRIPT_NAME status
  $SCRIPT_NAME capture [summary]

Commands:
  status            Show whether any submodule differs from the gitlink recorded in the parent repo.
  capture [summary] Export submodule changes into ${ARTIFACT_ROOT}/<timestamp>/ inside the parent repo.

Options via environment:
  CODEX_ARTIFACT_ROOT   Override the artifact directory name. Default: codex-artifacts
  CODEX_STAGE_ARTIFACTS If set to 1, git add the generated artifact bundle in the parent repo.
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

note() {
  printf '%s\n' "$*"
}

require_parent_repo() {
  ROOT=$(git rev-parse --show-toplevel 2> /dev/null || true)
  [[ -n "$ROOT" ]] || die "Run this script inside the parent repo checkout."
  cd "$ROOT"
  [[ -f .gitmodules ]] || die "No .gitmodules found in $ROOT."
}

list_submodules() {
  git config -f .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}'
}

get_gitlink_sha() {
  local path="$1"
  git ls-files -s -- "$path" | awk '$1 == "160000" { print $2; exit }'
}

ensure_bundle_dirs() {
  local bundle_root="$1"
  mkdir -p "$bundle_root/submodules"
}

file_count_from_nul_stream() {
  tr '\0' '\n' | sed '/^$/d' | wc -l | awk '{print $1}'
}

capture_one_submodule() {
  local path="$1"
  local bundle_root="$2"
  local summary="$3"
  local bundle="$bundle_root/submodules/$path"
  local bundle_rel="${bundle#"$ROOT/"}"
  local overlay="$bundle/overlay"
  local overlay_rel="${overlay#"$ROOT/"}"
  local base_sha head_sha remote_url branch_name status_file deleted_file untracked_file changed_tmp untracked_tmp
  local changed_count untracked_count dirty=0

  if [[ ! -d "$path" ]]; then
    note "SKIP  $path (directory missing)"
    return 1
  fi

  if ! git -C "$path" rev-parse --git-dir > /dev/null 2>&1; then
    note "SKIP  $path (not initialized as a git repo)"
    return 1
  fi

  base_sha=$(get_gitlink_sha "$path")
  if [[ -z "$base_sha" ]]; then
    base_sha=$(git -C "$path" rev-parse HEAD)
  fi

  head_sha=$(git -C "$path" rev-parse HEAD)
  remote_url=$(git -C "$path" config --get remote.origin.url || true)
  branch_name=$(git -C "$path" rev-parse --abbrev-ref HEAD || true)

  changed_tmp=$(mktemp)
  untracked_tmp=$(mktemp)
  git -C "$path" diff -z --name-only "$base_sha" -- . > "$changed_tmp"
  git -C "$path" ls-files -z --others --exclude-standard > "$untracked_tmp"

  changed_count=$(file_count_from_nul_stream < "$changed_tmp")
  untracked_count=$(file_count_from_nul_stream < "$untracked_tmp")

  if [[ "$head_sha" != "$base_sha" || "$changed_count" != "0" || "$untracked_count" != "0" ]]; then
    dirty=1
  fi

  if [[ "$dirty" -eq 0 ]]; then
    rm -f "$changed_tmp" "$untracked_tmp"
    note "CLEAN $path"
    return 1
  fi

  mkdir -p "$overlay"
  status_file="$bundle/status.txt"
  deleted_file="$bundle/deleted-files.txt"
  untracked_file="$bundle/untracked-files.txt"

  git -C "$path" status --short --branch --untracked=all > "$status_file"
  : > "$deleted_file"
  : > "$untracked_file"

  git -C "$path" diff --binary --full-index "$base_sha" -- . > "$bundle/changes.patch"

  while IFS= read -r -d '' relpath; do
    [[ -n "$relpath" ]] || continue
    if [[ -e "$path/$relpath" || -L "$path/$relpath" ]]; then
      mkdir -p "$overlay/$(dirname "$relpath")"
      cp -a "$path/$relpath" "$overlay/$relpath"
    else
      printf '%s\n' "$relpath" >> "$deleted_file"
    fi
  done < "$changed_tmp"

  while IFS= read -r -d '' relpath; do
    [[ -n "$relpath" ]] || continue
    mkdir -p "$overlay/$(dirname "$relpath")"
    cp -a "$path/$relpath" "$overlay/$relpath"
    printf '%s\n' "$relpath" >> "$untracked_file"
  done < "$untracked_tmp"

  cat > "$bundle/APPLY.md" << APPLY
# Apply bundle for $path

Summary: ${summary}
Recorded gitlink/base SHA: $base_sha
Working tree HEAD at capture time: $head_sha
Remote: ${remote_url:-<none>}
Branch/HEAD name: ${branch_name:-<unknown>}

Recommended outside Codex Cloud:

1. Open a normal checkout of the real repo for this submodule.
2. Check out the recorded base SHA (or a compatible branch tip if you want to hand-merge):

   git checkout $base_sha

3. Apply the tracked-file patch:

   PARENT_REPO=/absolute/path/to/EM3555-codex
   git apply --3way "\$PARENT_REPO/$bundle_rel/changes.patch"

4. Overlay copied files (this captures untracked files and also gives you a human-readable copy of every changed file):

   PARENT_REPO=/absolute/path/to/EM3555-codex
   ( cd "\$PARENT_REPO/$overlay_rel" && tar -cf - . ) | tar -xf -

5. Review deletions listed in deleted-files.txt and remove them manually if appropriate.
6. Inspect the result, commit in the real submodule repo, and open the PR from there.
APPLY

  cat > "$bundle/METADATA.txt" << META
submodule_path=$path
summary=$summary
recorded_base_sha=$base_sha
capture_head_sha=$head_sha
remote_url=$remote_url
branch_name=$branch_name
changed_tracked_file_count=$changed_count
untracked_file_count=$untracked_count
artifact_path=$bundle
META

  rm -f "$changed_tmp" "$untracked_tmp"
  note "DIRTY $path -> $bundle"
  return 0
}

write_top_level_manifest() {
  local bundle_root="$1"
  local summary="$2"
  local changed_paths_file="$bundle_root/.changed-submodules"
  local manifest="$bundle_root/MANIFEST.md"

  {
    printf '# Codex submodule export\n\n'
    printf 'Summary: %s\n\n' "$summary"
    printf 'This bundle exists because Codex Cloud can only push/PR from the parent repo.\n'
    printf 'Submodule edits are preserved here as both a git patch and a file overlay.\n\n'

    if [[ -s "$changed_paths_file" ]]; then
      printf '## Included submodules\n\n'
      while IFS= read -r path; do
        [[ -n "$path" ]] || continue
        printf -- '- `%s`\n' "$path"
      done < "$changed_paths_file"
      printf '\n'

      printf '## Apply flow outside Codex Cloud\n\n'
      printf '%s\n\n' "For each submodule listed above, open the matching real repository and follow that submodule bundle's \`APPLY.md\`."

      printf '## Notes for the parent repo PR\n\n'
      printf -- '- Commit the generated `codex-artifacts/...` files in the parent repo.\n'
      printf -- '- Do not rely on a changed submodule gitlink as the transport mechanism.\n'
      printf -- '- In the PR description, reference this bundle path so you can replay it later.\n'
    else
      printf 'No submodule changes were detected.\n'
    fi
  } > "$manifest"
}

cmd_status() {
  local path base_sha head_sha changed_count untracked_count changed_tmp untracked_tmp
  local found_dirty=0

  require_parent_repo
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue

    if [[ ! -d "$path" ]] || ! git -C "$path" rev-parse --git-dir > /dev/null 2>&1; then
      printf 'SKIP  %s (not initialized)\n' "$path"
      continue
    fi

    base_sha=$(get_gitlink_sha "$path")
    if [[ -z "$base_sha" ]]; then
      base_sha=$(git -C "$path" rev-parse HEAD)
    fi
    head_sha=$(git -C "$path" rev-parse HEAD)

    changed_tmp=$(mktemp)
    untracked_tmp=$(mktemp)
    git -C "$path" diff -z --name-only "$base_sha" -- . > "$changed_tmp"
    git -C "$path" ls-files -z --others --exclude-standard > "$untracked_tmp"
    changed_count=$(file_count_from_nul_stream < "$changed_tmp")
    untracked_count=$(file_count_from_nul_stream < "$untracked_tmp")
    rm -f "$changed_tmp" "$untracked_tmp"

    if [[ "$head_sha" != "$base_sha" || "$changed_count" != "0" || "$untracked_count" != "0" ]]; then
      printf 'DIRTY %s base=%s head=%s tracked=%s untracked=%s\n' "$path" "$base_sha" "$head_sha" "$changed_count" "$untracked_count"
      found_dirty=1
    else
      printf 'CLEAN %s\n' "$path"
    fi
  done < <(list_submodules)

  return "$found_dirty"
}

cmd_capture() {
  local summary="${1:-manual export}"
  local stamp bundle_root path captured_any=0

  require_parent_repo
  stamp=$(date -u +%Y%m%dT%H%M%SZ)
  bundle_root="$ROOT/$ARTIFACT_ROOT/$stamp"
  ensure_bundle_dirs "$bundle_root"
  : > "$bundle_root/.changed-submodules"

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    if capture_one_submodule "$path" "$bundle_root" "$summary"; then
      printf '%s\n' "$path" >> "$bundle_root/.changed-submodules"
      captured_any=1
    fi
  done < <(list_submodules)

  write_top_level_manifest "$bundle_root" "$summary"
  printf '%s\n' "$stamp" > "$ROOT/$ARTIFACT_ROOT/LATEST"

  if [[ "$captured_any" -eq 0 ]]; then
    rm -f "$bundle_root/.changed-submodules"
    note "No submodule deltas found relative to the parent repo gitlinks."
    note "Created manifest only: $bundle_root/MANIFEST.md"
  else
    rm -f "$bundle_root/.changed-submodules"
    note "Bundle created: $bundle_root"
    note "Review:        $bundle_root/MANIFEST.md"
    if [[ "${CODEX_STAGE_ARTIFACTS:-0}" == "1" ]]; then
      git add "$ARTIFACT_ROOT/$stamp" "$ARTIFACT_ROOT/LATEST"
      note "Staged:        $ARTIFACT_ROOT/$stamp and $ARTIFACT_ROOT/LATEST"
    fi
  fi
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    status)
      shift
      cmd_status "$@"
      ;;
    capture)
      shift
      cmd_capture "${1:-manual export}"
      ;;
    -h | --help | help | "")
      usage
      ;;
    *)
      usage >&2
      die "Unknown command: $cmd"
      ;;
  esac
}

main "$@"
