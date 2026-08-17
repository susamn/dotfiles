#!/usr/bin/env bats
#
# Invariants for the configuration this repo owns.
#
# Every case here corresponds to something that actually went wrong: a profile
# pointing at a path that did not exist, playlists leaking into the music
# directory, per-profile unit files duplicating a systemd template, a generated
# file getting committed, and a skill reference nothing pointed at.
#
# These are cheap, total checks -- no network, no systemd, no installed state --
# so they run anywhere the repo is checked out.

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

REPO="${BATS_TEST_DIRNAME}/../.."
PROFILES="$REPO/.config/rclone-sync-profiles"
SERVICES="$REPO/workspace/services"
SKILL_DIR="$REPO/workspace/aistuff/skills/dotfiles-management"

# ── rclone sync profiles ─────────────────────────────────────────────────────

@test "every rclone profile declares the fields the engine requires" {
  # rclone-sync.sh exits if REMOTE, LOCAL_PATH or SYNC_TYPE is missing, and it
  # does so inside a systemd oneshot where nobody is watching.
  for conf in "$PROFILES"/*.conf; do
    for key in REMOTE LOCAL_PATH SYNC_TYPE; do
      run grep -qE "^${key}=" "$conf"
      assert_success "$(basename "$conf") is missing ${key}"
    done
  done
}

@test "every rclone profile uses a SYNC_TYPE the engine understands" {
  for conf in "$PROFILES"/*.conf; do
    local value
    value=$(grep -E '^SYNC_TYPE=' "$conf" | head -1 | cut -d= -f2- | tr -d '"')
    case "$value" in
      one|bidirectional|mount) ;;
      *) fail "$(basename "$conf"): unknown SYNC_TYPE '$value'" ;;
    esac
  done
}

@test "a one-way profile declares its DIRECTION" {
  # DIRECTION defaults to local-to-remote in the engine. For a profile meant to
  # pull, silently defaulting to push is a destructive difference.
  for conf in "$PROFILES"/*.conf; do
    grep -qE '^SYNC_TYPE="?one"?' "$conf" || continue
    run grep -qE '^DIRECTION=' "$conf"
    assert_success "$(basename "$conf") is SYNC_TYPE=one but declares no DIRECTION"
  done
}

@test "the music tracks profile keeps playlists out of the music directory" {
  # music-tracks syncs a parent of the playlists path, so without these excludes
  # every playlist lands in MPD's music_directory alongside the audio.
  local conf="$PROFILES/music-tracks.conf"
  [ -f "$conf" ] || skip "music-tracks profile not present"
  run grep -q -- '--exclude=\*\.m3u' "$conf"
  assert_success "music-tracks must exclude *.m3u"
  run grep -q -- '--exclude=/music-metadata/\*\*' "$conf"
  assert_success "music-tracks must exclude /music-metadata/**"
}

@test "no profile still filters on m3u8" {
  # The library is .m3u only; an m3u8 filter is a no-op that reads as protection.
  run grep -rl 'm3u8' "$PROFILES"
  assert_failure "m3u8 filters remain: $output"
}

# ── systemd units ────────────────────────────────────────────────────────────

@test "every shipped unit has an [Install] or is a plain target" {
  for unit in "$SERVICES"/*.service "$SERVICES"/*.timer; do
    [ -e "$unit" ] || continue
    case "$(basename "$unit")" in
      # oneshot services driven by a timer are pulled in by that timer
      rclone-sync@.service|sys-manager-cleanup.service) continue ;;
    esac
    run grep -q '^\[Install\]' "$unit"
    assert_success "$(basename "$unit") has no [Install] section"
  done
}

@test "the personal-services target is system scope" {
  # multi-user.target does not exist in the user manager: a user unit wanting it
  # enables without error and then never activates.
  local target="$SERVICES/personal-services.target"
  [ -f "$target" ] || skip "target not present"
  run grep -qE '^WantedBy=.*multi-user\.target' "$target"
  assert_success "personal-services.target must be WantedBy=multi-user.target"
}

@test "no per-profile unit files duplicate the rclone templates" {
  # A sync needs a profile and nothing else -- the profile name is the systemd
  # instance. Hand-written per-profile units double-schedule the same sync.
  for conf in "$PROFILES"/*.conf; do
    local name
    name=$(basename "$conf" .conf)
    for stray in "$SERVICES/rclone-sync-${name}."* "$SERVICES/${name}."*; do
      [ -e "$stray" ] && fail "per-profile unit duplicates a template: $(basename "$stray")"
    done
  done
  true
}

@test "no ExecStart relies on shell globbing" {
  # systemd does not expand globs in ExecStart; the cleanup unit shipped broken
  # this way and silently deleted nothing.
  run grep -n 'ExecStart=.*\*' "$SERVICES"/*.service
  assert_failure "glob in ExecStart: $output"
}

@test "templated units keep the raw @USER@ placeholder" {
  # Substitution happens at install time. A committed, already-substituted unit
  # would install the wrong account on every other machine.
  for unit in "$SERVICES"/rclone-sync@.service "$SERVICES"/rclone-mount@.service; do
    [ -e "$unit" ] || continue
    run grep -q '@USER@' "$unit"
    assert_success "$(basename "$unit") lost its @USER@ placeholder"
  done
}

# ── generated files must not be committed ────────────────────────────────────

@test "mpd.conf is not tracked, only its template" {
  # mpd.conf is regenerated by 'mpdc configure' from mpd.conf.bak. Committing the
  # generated file makes edits to it look durable when they are discarded.
  run git -C "$REPO" ls-files --error-unmatch .config/mpd/mpd.conf
  assert_failure "mpd.conf is generated and must not be tracked"

  run git -C "$REPO" ls-files --error-unmatch .config/mpd/mpd.conf.bak
  assert_success "the mpd.conf.bak template must be tracked"
}

@test "no agent instruction file is tracked" {
  # These are generated from AGENTS-TEMPLATE.md on every do-stow.sh run.
  run git -C "$REPO" ls-files 'AGENTS.md' 'CLAUDE.md' '.claude/CLAUDE.md'
  assert_output "" "generated agent instructions must not be tracked"
}

# ── stow configuration ───────────────────────────────────────────────────────

@test "stow-local-ignore still replicates stow's built-in defaults" {
  # This file REPLACES stow's built-in ignore list rather than extending it, so
  # dropping an entry silently starts stowing .git into \$HOME.
  for pattern in '\.git' '\.gitignore' '\.gitmodules' 'CVS' '\.stow-local-ignore'; do
    run grep -qF "$pattern" "$REPO/.stow-local-ignore"
    assert_success ".stow-local-ignore lost the built-in default: $pattern"
  done
}

@test "aistuff is excluded from stow" {
  run grep -qE '\^workspace/aistuff\$' "$REPO/.stow-local-ignore"
  assert_success "workspace/aistuff must never be stowed into \$HOME"
}

# ── CI configuration ─────────────────────────────────────────────────────────

@test "no workflow checks out every submodule" {
  # `submodules: true` fetches .config/_secured, which is private. The runner
  # cannot clone it and aborts the entire checkout before a single test runs.
  # Fetch the specific submodules a job needs instead.
  for wf in "$REPO"/.github/workflows/*.yml; do
    [ -e "$wf" ] || continue
    if grep -E '^\s*submodules:\s*(true|recursive)\s*$' "$wf" >/dev/null; then
      fail "$(basename "$wf") checks out all submodules; one of them is private"
    fi
  done
  true
}

# ── skill references ─────────────────────────────────────────────────────────

@test "every dotfiles-management reference is routed from SKILL.md" {
  # A reference nothing points at is one an agent never reads.
  # Skips rather than fails when the skills submodule is not checked out: CI
  # deliberately does not fetch every submodule, because one of them is private.
  [ -f "$SKILL_DIR/SKILL.md" ] || skip "skills submodule not checked out"
  [ -d "$SKILL_DIR/references" ] || skip "no references directory"
  for ref in "$SKILL_DIR/references"/*.md; do
    local name
    name=$(basename "$ref")
    run grep -q "references/$name" "$SKILL_DIR/SKILL.md"
    assert_success "SKILL.md does not route to $name"
  done
}

@test "SKILL.md stays within the authoring budget" {
  [ -f "$SKILL_DIR/SKILL.md" ] || skip "skills submodule not checked out"
  run bash -c "wc -l < '$SKILL_DIR/SKILL.md'"
  assert_success
  [ "$output" -le 200 ] || fail "SKILL.md is $output lines; the ceiling is 200"
}
