#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

SCRIPT_PATH="${BATS_TEST_DIRNAME}/../scripts/gitb.sh"

setup() {
  TMPDIR=$(mktemp -d)
  cd "$TMPDIR"
  git init -q
  git checkout -q -b test-branch
  git remote add origin "git@github.com:user/repo.git"

  # Mocks
  PATH="$TMPDIR/mocks:$PATH"
  mkdir -p "$TMPDIR/mocks"
  echo -e '#!/bin/bash\necho "Opening: $1"' > "$TMPDIR/mocks/xdg-open"
  chmod +x "$TMPDIR/mocks/xdg-open"
  echo -e '#!/bin/bash\necho "Opening: $1"' > "$TMPDIR/mocks/open"
  chmod +x "$TMPDIR/mocks/open"
  echo -e '#!/bin/bash\necho "Opening: $1"' > "$TMPDIR/mocks/start"
  chmod +x "$TMPDIR/mocks/start"
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "opens current branch URL on GitHub" {
  git remote set-url origin "git@github.com:user/repo.git"
  run bash "$SCRIPT_PATH"
  assert_success
  assert_output --partial "https://github.com/user/repo/tree/test-branch"
  assert_output --partial "Opening: https://github.com/user/repo/tree/test-branch"
}

@test "opens latest PR search URL on GitLab with -pr flag" {
  git remote set-url origin "https://gitlab.com/user/repo.git"
  run bash "$SCRIPT_PATH" -pr
  assert_success
  assert_output --partial "https://gitlab.com/user/repo/-/merge_requests?scope=all&state=opened&search=test-branch"
  assert_output --partial "Opening: https://gitlab.com/user/repo/-/merge_requests?scope=all&state=opened&search=test-branch"
}

@test "shows error when not a git repo" {
  cd /
  run bash "$SCRIPT_PATH"
  assert_failure
  assert_output --partial "Not a Git repository"
}

@test "shows error when no remote origin" {
  git remote remove origin
  run bash "$SCRIPT_PATH"
  assert_failure
  assert_output --partial "No remote origin found"
}

