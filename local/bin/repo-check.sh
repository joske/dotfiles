#!/usr/bin/env bash

echo "Checking all git repositories in $(pwd)"

find . -name .git -print0 |
  while IFS= read -r -d '' marker; do
    repo=$(dirname "$marker")

    git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || continue

    if ! git -C "$repo" diff --quiet --diff-filter=U; then
      echo "$repo => CONFLICTS"
    elif ! git -C "$repo" diff --quiet || ! git -C "$repo" diff --cached --quiet; then
      echo "$repo => Dirty"
    fi
  done
