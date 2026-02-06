#!/usr/bin/env bash

set -euo pipefail

SOURCE_REF="${SOURCE_REF:-master}"
TARGET_REF="${TARGET_REF:-headless}"
REPO_ROOT="$(pwd)"
WORKTREE_DIR=""
RESOLVED_SOURCE_REF=""
RESOLVED_TARGET_REF=""

resolve_ref() {
  local ref="$1"
  if git rev-parse --verify "$ref" >/dev/null 2>&1; then
    echo "$ref"
    return 0
  fi

  local remote_ref="origin/$ref"
  if git rev-parse --verify "$remote_ref" >/dev/null 2>&1; then
    echo "$remote_ref"
    return 0
  fi

  return 1
}

cleanup() {
  cd "$REPO_ROOT"
  if [[ -n "$WORKTREE_DIR" && -d "$WORKTREE_DIR" ]]; then
    git -C "$WORKTREE_DIR" merge --abort >/dev/null 2>&1 || true
    git worktree remove --force "$WORKTREE_DIR" >/dev/null 2>&1 || true
    rm -rf "$WORKTREE_DIR" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree must be clean before running sync check."
  echo "Commit, stash, or discard local changes and retry."
  exit 1
fi

if ! RESOLVED_SOURCE_REF="$(resolve_ref "$SOURCE_REF")"; then
  echo "Source ref '$SOURCE_REF' does not exist."
  exit 1
fi

if ! RESOLVED_TARGET_REF="$(resolve_ref "$TARGET_REF")"; then
  echo "Target ref '$TARGET_REF' does not exist."
  exit 1
fi

WORKTREE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/headless-sync-check.XXXXXX")"

echo "Creating temporary worktree from '$TARGET_REF' ($RESOLVED_TARGET_REF): $WORKTREE_DIR"
git worktree add --quiet --detach "$WORKTREE_DIR" "$RESOLVED_TARGET_REF"

cd "$WORKTREE_DIR"

echo "Merging '$SOURCE_REF' ($RESOLVED_SOURCE_REF) into '$TARGET_REF' ($RESOLVED_TARGET_REF) (no-commit dry run)"
if ! git merge --no-commit --no-ff "$RESOLVED_SOURCE_REF"; then
  echo "Merge conflicts detected while applying '$SOURCE_REF' into '$TARGET_REF'."
  echo "Conflicting files:"
  git diff --name-only --diff-filter=U
  exit 1
fi

echo "Merge simulation succeeded. Running headless build validation..."
set -o pipefail
xcodebuild -workspace alt-tab-macos.xcworkspace -scheme Headless build | scripts/xcbeautify
scripts/headless/verify_minimal_headless.sh

echo "Running unit tests validation..."
xcodebuild test -workspace alt-tab-macos.xcworkspace -scheme Test -configuration Release | scripts/xcbeautify

git merge --abort

echo "Sync check passed for '$SOURCE_REF' -> '$TARGET_REF'."
