#!/usr/bin/env bash
# music-trimmer -- fzf-pick an audio file, mark a range by ear while it plays,
# write <name>-trimmed.<ext> next to the original with a lossless stream copy.
#
#   [  set IN at the current playback position
#   ]  set OUT at the current playback position
#   s  save the marked range
#
# Playback is a background mpv driven over its JSON IPC socket; this script
# only reads keys and asks mpv where it is.

set -uo pipefail

# Fractional `read -t`, mapfile and ${var,,} all need bash 4. macOS still ships
# bash 3.2 as /bin/bash, so say so plainly instead of failing in a strange way.
if [[ -z "${BASH_VERSINFO:-}" || "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  printf 'music-trimmer needs bash 4 or newer (this is %s).\n' "${BASH_VERSION:-unknown}" >&2
  printf 'On macOS: brew install bash, and make sure it comes first in PATH.\n' >&2
  exit 1
fi

ROOT="${HOME}"
SOCK=""
MPV_PID=""
PREVIEW_PID=""
FILE=""
DURATION=0
IN_POINT=""
OUT_POINT=""
STATUS=""
BAR_WIDTH=34
LAST_FRAME=""
HDR_NAME=""
HDR_DIR=""
KEYS=""
EL=$'\033[K'   # erase to end of line
FADE=1          # seconds of fade in/out; 0 disables
COPY_ONLY=0     # -c: lossless stream copy, which rules out fades
FADE_LABEL=""

# Formats where a re-encode loses quality, so the source bitrate is matched.
LOSSY_EXTS=" mp3 aac m4a ogg opus wma "

# Decodable but not writable by ffmpeg -- these get saved as FLAC instead.
LOSSLESS_ONLY_EXTS=" ape alac "

BLOCK_FULL='█'
BLOCK_EMPTY='░'
TMPDIR_PRIV=""

AUDIO_EXTS=(mp3 flac m4a aac ogg opus wav wma aiff aif alac ape mka)

# Directories never worth walking when hunting for music. Without these a scan
# of $HOME spends most of its time in caches and package trees.
FD_PRUNE=(.git node_modules .cache .local .venv venv __pycache__ .npm .cargo
          .rustup .gradle .m2 .steam snap Trash .Trash-1000 .mozilla
          .thunderbird go/pkg .var)

# ---------------------------------------------------------------- utilities

die() { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }

need() {
  local missing=()
  for c in "$@"; do command -v "$c" >/dev/null 2>&1 || missing+=("$c"); done
  ((${#missing[@]})) && die "missing required command(s): ${missing[*]}"
}

# Anything that came from a filename or from ffmpeg's stderr is untrusted: a
# track called $'\033[2J\033[1;1H...' would otherwise repaint or scroll this
# TUI when its name is drawn. Strip every control character and cap the length.
clean() {
  printf '%s' "$1" | tr -d '\000-\037\177' | cut -c1-"${2:-200}"
}

# POSIX single-quoting. The scan is handed to fzf as a string that fzf runs via
# /bin/sh, so bash's %q is not safe here: on a path with a newline or tab it
# emits $'...', which a POSIX sh cannot parse.
shq() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

# realpath(1) is not on every macOS; this needs no external command at all.
abspath() {
  local d b
  d="$(dirname -- "$1")"
  b="$(basename -- "$1")"
  if [[ -d "$1" ]]; then
    (cd -- "$1" 2>/dev/null && pwd -P)
  else
    d="$(cd -- "$d" 2>/dev/null && pwd -P)" && printf '%s/%s' "$d" "$b"
  fi
}

usage() {
  cat <<EOF
usage: music-trimmer [-d DIR] [-F SECS] [-c] [FILE]

  -d DIR   start the file picker in DIR (default: \$HOME)
  -F SECS  fade in/out length, 0 to disable (default: 1)
  -c       lossless stream copy -- faster and bit-exact, but no fades and
           the cut snaps to a frame boundary
  FILE     skip the picker and open FILE directly
  -h       this help
EOF
  exit 0
}

# seconds -> M:SS.s (or H:MM:SS.s past an hour)
fmt() {
  local t="${1:-}"
  [[ -z "$t" || "$t" == "null" ]] && { printf -- '--:--'; return; }
  awk -v t="$t" 'BEGIN{
    if (t < 0) t = 0
    h = int(t/3600); m = int((t%3600)/60); s = t - h*3600 - m*60
    if (h > 0) printf "%d:%02d:%04.1f", h, m, s
    else       printf "%d:%04.1f", m, s
  }'
}

# ------------------------------------------------------------ mpv IPC layer

mpv_cmd() {
  # $* is the JSON command array body, e.g. '"seek", 5, "relative"'
  printf '{"command":[%s]}\n' "$*" | socat - "$SOCK" 2>/dev/null
}

mpv_get() {
  local out
  out="$(mpv_cmd "\"get_property\", \"$1\"")" || return 1
  printf '%s' "$out" | jq -r 'select(.error=="success") | .data' 2>/dev/null
}

mpv_alive() { [[ -n "$MPV_PID" ]] && kill -0 "$MPV_PID" 2>/dev/null; }

start_mpv() {
  SOCK="$TMPDIR_PRIV/ipc.sock"
  mpv --no-video --no-terminal --really-quiet \
      --keep-open=yes --idle=yes --pause=no \
      --input-ipc-server="$SOCK" \
      -- "$FILE" &
  MPV_PID=$!

  local i=0
  while [[ ! -S "$SOCK" ]]; do
    ((i++ > 100)) && die "mpv did not open its IPC socket"
    mpv_alive || die "mpv exited immediately -- can it play '$FILE'?"
    sleep 0.05
  done
}

cleanup() {
  stty "$STTY_SAVE" 2>/dev/null
  [[ -n "$PREVIEW_PID" ]] && kill "$PREVIEW_PID" 2>/dev/null
  [[ -n "$MPV_PID" ]] && kill "$MPV_PID" 2>/dev/null
  [[ -n "$TMPDIR_PRIV" && -d "$TMPDIR_PRIV" ]] && rm -rf "$TMPDIR_PRIV"
  printf '\033[?1049l\033[?25h'
}

# ------------------------------------------------------------- file picking

# Network filesystems mounted under the search root. --follow happily walks
# into an rclone mount and turns a 0.4s scan into a 25s one, so they are pruned
# unless the search root is inside one, i.e. you asked for it on purpose.
fuse_mounts() {
  local root="$1" m fstype
  while read -r m fstype; do
    case "$fstype" in
      fuse*|smbfs|afpfs|nfs|webdav|osxfuse|macfuse) ;;
      *) continue ;;
    esac
    [[ "$m" == /sys/* || "$m" == /run/* || "$m" == /proc/* ]] && continue
    [[ "$root" == "$m" || "$root" == "$m"/* ]] && continue
    printf '%s\n' "$m"
  done < <(
    if command -v findmnt >/dev/null 2>&1; then
      findmnt -ln -o TARGET,FSTYPE 2>/dev/null
    else
      # macOS/BSD: "device on /mount/point (type, opts)" -> "/mount/point type"
      mount 2>/dev/null | sed -n 's|^.* on \(.*\) (\([^,)]*\).*|\1 \2|p'
    fi
  )
}

# The result is handed to fzf as FZF_DEFAULT_COMMAND rather than piped in, so
# that fzf owns the fd process and kills it the moment you pick something.
# Piping it in instead leaves the command substitution blocked on an fd still
# walking $HOME, and makes pipefail read fd's SIGPIPE as "user cancelled".
fd_cmd() {
  local type="$1" dir="$2" e
  local args=(--type "$type" --follow)
  for e in "${FD_PRUNE[@]}"; do args+=(--exclude "$e"); done
  while IFS= read -r e; do args+=(--exclude "$e"); done < <(fuse_mounts "$dir")
  if [[ "$type" == f ]]; then
    for e in "${AUDIO_EXTS[@]}"; do args+=(-e "$e"); done
  fi
  args+=(. "$dir")
  local qs='fd'
  for e in "${args[@]}"; do qs+=" $(shq "$e")"; done
  printf '%s 2>/dev/null' "$qs"
}

# Lists folders under $HOME, but an absolute path typed at the prompt is taken
# literally, so somewhere outside $HOME is still reachable. Returns non-zero on
# cancel or a dud path; the caller stays on the current root either way.
pick_dir() {
  local out rc q d
  out="$(FZF_DEFAULT_COMMAND="$(fd_cmd d "$HOME")" \
         fzf --prompt='folder> ' \
             --header='pick a folder, or type a path and press enter' \
             --height=80% --reverse --border=rounded --scheme=path \
             --print-query)"
  rc=$?
  q="$(sed -n 1p <<<"$out")"
  d="$(sed -n 2p <<<"$out")"
  case "$rc" in
    0) ;;        # something in the list was chosen
    1) d="" ;;   # nothing matched -- the query may still be a real path
    *) return 1 ;;  # 130: aborted with esc/ctrl-c
  esac
  if [[ -z "$d" && -n "$q" ]]; then
    d="${q/#\~/$HOME}"
  fi
  [[ -n "$d" && -d "$d" ]] || return 1
  ROOT="$(abspath "$d")"
}

pick_file() {
  local key sel out
  while :; do
    out="$(FZF_DEFAULT_COMMAND="$(fd_cmd f "$ROOT")" \
           fzf --prompt='track> ' \
               --header="root: ${ROOT/#$HOME/\~}   (ctrl-f: change folder)" \
               --height=80% --reverse --border=rounded --scheme=path \
               --expect=ctrl-f)" || return 1
    key="$(sed -n 1p <<<"$out")"
    sel="$(sed -n 2p <<<"$out")"
    if [[ "$key" == "ctrl-f" ]]; then
      pick_dir   # on cancel or a bad path, fall through on the current root
      continue
    fi
    [[ -z "$sel" ]] && return 1
    FILE="$sel"
    return 0
  done
}

# ------------------------------------------------------------------ drawing

# The keymap never changes, so it is rendered once rather than on every frame.
build_keys() {
  local k
  printf -v k '  \033[90m[\033[0m set in   \033[90m]\033[0m set out   \033[90mc\033[0m clear   \033[90mi/o\033[0m jump to mark'
  KEYS="$k$EL"$'\n'
  printf -v k '  \033[90m<-/->\033[0m 5s   \033[90m,/.\033[0m 1s   \033[90mup/dn\033[0m 30s   \033[90mg\033[0m start'
  KEYS+="$k$EL"$'\n'
  printf -v k '  \033[90mspace\033[0m pause   \033[90mp\033[0m preview   \033[90ms\033[0m save   \033[90mq\033[0m quit'
  KEYS+="$k$EL"$'\n'
}

# Assembles the whole frame into one string and writes it with a single printf,
# overwriting lines in place (\033[K) rather than wiping the screen first.
# Clearing up front and then filling the screen with a dozen writes -- each one
# waiting on a basename or awk subprocess -- is what made this flicker. All the
# arithmetic and time formatting is done in one awk call for the same reason.
draw() {
  local pos="$1" paused="$2"
  local vals filled in_col out_col t_pos t_dur t_in t_out t_len bar state f line i

  mapfile -t vals < <(awk -v p="$pos" -v d="$DURATION" -v w="$BAR_WIDTH" \
                          -v i="$IN_POINT" -v o="$OUT_POINT" '
    function fmt(t,   h, m, s) {
      if (t == "") return "--:--"
      if (t < 0) t = 0
      h = int(t/3600); m = int((t%3600)/60); s = t - h*3600 - m*60
      if (h > 0) return sprintf("%d:%02d:%04.1f", h, m, s)
      return sprintf("%d:%04.1f", m, s)
    }
    BEGIN {
      fl = (d > 0) ? int(p/d*w) : 0
      if (fl < 0) fl = 0
      if (fl > w) fl = w
      ic = (i != "" && d > 0) ? int(i/d*w) : -1
      oc = (o != "" && d > 0) ? int(o/d*w) : -1
      ln = (i != "" && o != "") ? fmt(o - i) : "--"
      print fl; print ic; print oc
      print fmt(p); print fmt(d); print fmt(i); print fmt(o); print ln
    }')

  filled="${vals[0]}"; in_col="${vals[1]}"; out_col="${vals[2]}"
  t_pos="${vals[3]}"; t_dur="${vals[4]}"
  t_in="${vals[5]}";  t_out="${vals[6]}"; t_len="${vals[7]}"

  bar=""
  for ((i = 0; i < BAR_WIDTH; i++)); do
    if   ((i == in_col));  then bar+=$'\033[33m[\033[0m'
    elif ((i == out_col)); then bar+=$'\033[33m]\033[0m'
    elif ((i < filled));   then bar+=$'\033[36m'"$BLOCK_FULL"$'\033[0m'
    else                        bar+=$'\033[90m'"$BLOCK_EMPTY"$'\033[0m'
    fi
  done

  state=$'\033[32m>\033[0m playing'
  [[ "$paused" == "yes" ]] && state=$'\033[33m||\033[0m paused'

  f=$'\033[H'
  f+="  "$'\033[1;36m'"$HDR_NAME"$'\033[0m'"$EL"$'\n'
  f+="  "$'\033[90m'"$HDR_DIR"$'\033[0m'"$EL"$'\n'"$EL"$'\n'
  f+="  $state   "$'\033[1m'"$t_pos"$'\033[0m'" / $t_dur$EL"$'\n'
  f+="  $bar$EL"$'\n'"$EL"$'\n'
  printf -v line '  \033[33mIN\033[0m  %-12s  \033[33mOUT\033[0m %-12s  \033[35mlen\033[0m %-10s  \033[90m%s\033[0m' \
    "$t_in" "$t_out" "$t_len" "$FADE_LABEL"
  f+="$line$EL"$'\n'"$EL"$'\n'
  f+="$KEYS"
  if [[ -n "$STATUS" ]]; then
    printf -v line '  %b' "$STATUS"
    f+="$EL"$'\n'"$line$EL"$'\n'
  fi
  f+=$'\033[J'

  # nothing moved since the last frame -- do not touch the terminal at all
  [[ "$f" == "$LAST_FRAME" ]] && return
  LAST_FRAME="$f"
  printf '%s' "$f"
}

# ------------------------------------------------------------------ actions

preview() {
  [[ -z "$IN_POINT" ]] && { STATUS='\033[33mset IN first\033[0m'; return; }
  local end="${OUT_POINT:-$DURATION}"
  local len
  len="$(awk -v a="$IN_POINT" -v b="$end" 'BEGIN{print b-a}')"
  awk -v l="$len" 'BEGIN{exit !(l>0)}' || { STATUS='\033[31mIN is after OUT\033[0m'; return; }

  local was_paused
  was_paused="$(mpv_get pause)"
  mpv_cmd '"set_property", "pause", true' >/dev/null
  mpv --no-video --no-terminal --really-quiet \
      --start="$IN_POINT" --length="$len" -- "$FILE" &
  PREVIEW_PID=$!

  local key
  while kill -0 "$PREVIEW_PID" 2>/dev/null; do
    printf '\033[H\033[J\n  \033[36mpreviewing %s -> %s\033[0m   (any key stops)\n' \
      "$(fmt "$IN_POINT")" "$(fmt "$end")"
    if read -rsn1 -t 0.3 key; then
      kill "$PREVIEW_PID" 2>/dev/null
      break
    fi
  done
  wait "$PREVIEW_PID" 2>/dev/null
  PREVIEW_PID=""
  LAST_FRAME=""
  # leave playback as we found it
  [[ "$was_paused" != "true" ]] && mpv_cmd '"set_property", "pause", false' >/dev/null
  STATUS=""
}

# A fade is an audio filter, and a filter cannot run through -c copy, so asking
# for a fade means re-encoding. -c gives back the bit-exact copy and drops the
# fade. On a lossy source the re-encode matches the original bitrate so the one
# extra generation costs as little as possible.
save() {
  [[ -z "$IN_POINT" ]] && { STATUS='\033[33mset IN first\033[0m'; return; }
  local end="${OUT_POINT:-$DURATION}"
  local len
  len="$(awk -v a="$IN_POINT" -v b="$end" 'BEGIN{print b-a}')"
  awk -v l="$len" 'BEGIN{exit !(l>0.01)}' \
    || { STATUS='\033[31mrange is empty -- OUT must be after IN\033[0m'; return; }

  local dir base ext lext out n=1 changed=0
  dir="$(dirname -- "$FILE")"
  base="$(basename -- "$FILE")"
  # A name with no dot has no extension to inherit -- "${base##*.}" would
  # otherwise hand back the whole filename and build "song-trimmed.song".
  if [[ "$base" == *.* ]]; then
    ext="${base##*.}"
    base="${base%.*}"
  else
    ext=""
  fi
  lext="${ext,,}"

  # Some containers the picker lists can be decoded but not written: ffmpeg has
  # no ape encoder, and no muxer answers to a bare .alac. Re-encoding those to
  # FLAC keeps the audio lossless; a stream copy has nowhere to go, so it says so.
  if [[ -z "$ext" || "$LOSSLESS_ONLY_EXTS" == *" $lext "* ]]; then
    if (( COPY_ONLY )); then
      STATUS='\033[31mffmpeg cannot write this container -- drop -c to save as flac\033[0m'
      return
    fi
    ext="flac"; lext="flac"; changed=1
  fi

  out="$dir/$base-trimmed.$ext"
  while [[ -e "$out" ]]; do out="$dir/$base-trimmed-$((n++)).$ext"; done

  local -a enc=()
  local fade_used=0
  if (( COPY_ONLY )); then
    enc=(-c copy -avoid_negative_ts make_zero)
  else
    # a fade longer than half the clip would leave no steady section at all
    fade_used="$(awk -v f="$FADE" -v l="$len" \
      'BEGIN{ if (f <= 0) { print 0; exit } if (f > l/2) f = l/2; printf "%.3f", f }')"
    if awk -v f="$fade_used" 'BEGIN{exit !(f>0.01)}'; then
      enc=(-af "$(awk -v f="$fade_used" -v l="$len" \
        'BEGIN{printf "afade=t=in:st=0:d=%.3f,afade=t=out:st=%.3f:d=%.3f", f, l-f, f}')")
    fi
    if [[ "$LOSSY_EXTS" == *" $lext "* ]]; then
      local br
      br="$(ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate \
              -of csv=p=0 "$FILE" 2>/dev/null)"
      [[ "$br" =~ ^[0-9]+$ ]] && (( br > 0 )) && enc+=(-b:a "$br")
    fi
  fi

  local extra=()
  [[ "$lext" == "mp3" ]] && extra=(-id3v2_version 3)

  mpv_cmd '"set_property", "pause", true' >/dev/null
  LAST_FRAME=""
  printf '\033[H\033[J\n  \033[36mwriting %s ...\033[0m\n' "$(basename -- "$out")"

  if ffmpeg -hide_banner -loglevel error -y \
      -ss "$IN_POINT" -t "$len" -i "$FILE" \
      -map_metadata 0 -map 0:a ${enc[@]+"${enc[@]}"} ${extra[@]+"${extra[@]}"} \
      "$out" 2>"$ERRLOG"; then
    local note
    if (( COPY_ONLY )); then
      note="copy"
    elif awk -v f="$fade_used" 'BEGIN{exit !(f>0.01)}'; then
      note="$(awk -v f="$fade_used" 'BEGIN{printf "fade %.1fs", f}')"
    else
      note="no fade"
    fi
    (( changed )) && note="$note, written as flac"
    STATUS="\033[32msaved\033[0m $(clean "$(basename -- "$out")" 120)  \033[90m($(
      awk -v l="$len" 'BEGIN{printf "%.1fs", l}'), $note)\033[0m"
  else
    rm -f -- "$out"
    STATUS="\033[31mffmpeg failed:\033[0m $(clean "$(tail -n 2 "$ERRLOG" | tr '\n' ' ')" 160)"
  fi
}

# --------------------------------------------------------------------- main

while getopts ':d:F:ch' opt; do
  case "$opt" in
    d) ROOT="$OPTARG" ;;
    F) FADE="$OPTARG" ;;
    c) COPY_ONLY=1 ;;
    h) usage ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

need mpv ffmpeg ffprobe fzf socat jq fd awk

[[ -d "$ROOT" ]] || die "not a directory: $ROOT"
[[ "$FADE" =~ ^[0-9]*\.?[0-9]+$ ]] || die "-F wants a number of seconds, got: $FADE"

if (( COPY_ONLY )); then
  FADE_LABEL="lossless copy"
else
  FADE_LABEL="$(awk -v f="$FADE" 'BEGIN{ if (f > 0) printf "fade %.1fs", f; else printf "no fade" }')"
fi

if [[ $# -gt 0 ]]; then
  FILE="$1"
  [[ -f "$FILE" ]] || die "no such file: $FILE"
else
  pick_file || { printf 'nothing picked\n'; exit 0; }
fi
FILE="$(abspath "$FILE")"

HDR_NAME="$(clean "$(basename -- "$FILE")" 120)"
HDR_DIR="$(dirname -- "$FILE")"
HDR_DIR="$(clean "${HDR_DIR/#$HOME/\~}" 120)"
build_keys

DURATION="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$FILE")"
[[ "$DURATION" =~ ^[0-9]+([.][0-9]+)?$ ]] \
  || die "could not read a usable duration from $(clean "$FILE" 160)"

# One private 0700 directory for the IPC socket and ffmpeg's stderr. mktemp -u
# handed out a predictable name in a world-writable /tmp without creating it,
# which is a symlink race; it also put the X's mid-template, which BSD mktemp
# rejects outright.
TMPDIR_PRIV="$(mktemp -d "${TMPDIR:-/tmp}/music-trimmer.XXXXXX")" \
  || die "could not create a private temp directory"
chmod 700 "$TMPDIR_PRIV"
ERRLOG="$TMPDIR_PRIV/ffmpeg.err"
STTY_SAVE="$(stty -g)"
trap cleanup EXIT INT TERM

printf '\033[?25l'
start_mpv
stty -echo -icanon min 0 time 0
printf '\033[?1049h\033[H\033[J'   # alternate screen, entered once

while :; do
  mpv_alive || { STATUS='\033[31mmpv exited\033[0m'; }

  pos="$(mpv_get time-pos)"; [[ -z "$pos" || "$pos" == "null" ]] && pos=0
  paused="$(mpv_get pause)"; [[ "$paused" != "yes" && "$paused" != "true" ]] && paused=no || paused=yes

  draw "$pos" "$paused"

  IFS= read -rsn1 -t 0.25 key || continue
  STATUS=""

  # arrow keys arrive as ESC [ A/B/C/D
  if [[ "$key" == $'\033' ]]; then
    IFS= read -rsn2 -t 0.01 rest || rest=""
    case "$rest" in
      '[C') mpv_cmd '"seek", 5, "relative"'   >/dev/null ;;
      '[D') mpv_cmd '"seek", -5, "relative"'  >/dev/null ;;
      '[A') mpv_cmd '"seek", 30, "relative"'  >/dev/null ;;
      '[B') mpv_cmd '"seek", -30, "relative"' >/dev/null ;;
    esac
    continue
  fi

  case "$key" in
    '[') IN_POINT="$pos";  STATUS="\033[33mIN\033[0m  $(fmt "$pos")" ;;
    ']') OUT_POINT="$pos"; STATUS="\033[33mOUT\033[0m $(fmt "$pos")" ;;
    c)   IN_POINT=""; OUT_POINT=""; STATUS='marks cleared' ;;
    i)   [[ -n "$IN_POINT"  ]] && mpv_cmd "\"seek\", $IN_POINT, \"absolute\"" >/dev/null ;;
    o)   [[ -n "$OUT_POINT" ]] && mpv_cmd "\"seek\", $OUT_POINT, \"absolute\"" >/dev/null ;;
    g)   mpv_cmd '"seek", 0, "absolute"' >/dev/null ;;
    ',') mpv_cmd '"seek", -1, "relative"' >/dev/null ;;
    .)   mpv_cmd '"seek", 1, "relative"'  >/dev/null ;;
    ' ') mpv_cmd '"cycle", "pause"' >/dev/null ;;
    p)   preview ;;
    s)   save ;;
    q)   break ;;
  esac
done

exit 0
