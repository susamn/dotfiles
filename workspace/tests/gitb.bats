#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
  # Create temp dir with dummy git repo for testing
  TMPDIR=$(mktemp -d)
  cd "$TMPDIR"
  git init -q

  # Set a default branch name
  git checkout -q -b test-branch

  # Setup dummy remote URL; override in tests as needed
  git remote add origin "git@github.com:user/repo.git"

  # Mock xdg-open, open, start to just echo the URL
  PATH="$TMPDIR/mocks:$PATH"
  mkdir -p "$TMPDIR/mocks"
  echo -e '#!/bin/bash\necho "OPEN $1"' > "$TMPDIR/mocks/xdg-open"
  chmod +x "$TMPDIR/mocks/xdg-open"
  echo -e '#!/bin/bash\necho "OPEN $1"' > "$TMPDIR/mocks/open"
  chmod +x "$TMPDIR/mocks/open"
  echo -e '#!/bin/bash\necho "OPEN $1"' > "$TMPDIR/mocks/start"
  chmod +x "$TMPDIR/mocks/start"
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "opens current branch URL on GitHub" {
  git remote set-url origin "git@github.com:user/repo.git"
  run bash ../scripts/gitb.sh
  assert_success
  assert_output --partial "https://github.com/user/repo/tree/test-branch"
  assert_output --partial "OPEN https://github.com/user/repo/tree/test-branch"
}

@test "opens latest PR search URL on GitLab with -pr flag" {
  git remote set-url origin "https://gitlab.com/user/repo.git"
  run bash ../scripts/gitb.sh -pr
  assert_success
  assert_output --partial "https://gitlab.com/user/repo/-/merge_requests?scope=all&state=opened&search=test-branch"
  assert_output --partial "OPEN https://gitlab.com/user/repo/-/merge_requests?scope=all&state=opened&search=test-branch"
}

@test "shows error when not a git repo" {
  cd /
  run bash ../scripts/gitb.sh 
  assert_failure
  assert_output "Not a Git repository"
}

@test "shows error when no remote origin" {
  git remote remove origin
  run bash ../scripts/gitb.sh 
  assert_failure
  assert_output "No remote origin found"
}

