#!/bin/bash
# Streams the current synced-lyrics window to eww's `lyrics` deflisten
# variable as one JSON object per line, forever, one tick per second.
#
# Runs "mpdtui -lyrics-line" once per tick (its own 4-line window: 1 line
# of context above the current line, the current line, 2 lines below --
# see mpdtui's internal/lyricsline) and pushes the result straight
# through -- except when the *current* line (line 2) has changed since
# the previous tick: then it first pushes "reveal: false" (still showing
# the *old* current text, dimmed) and sleeps briefly before pushing
# "reveal: true" with the new text at full opacity, so eww.yuck's
# opacity transition on the current-line label has two distinct states
# to animate between. A poll-based (defpoll) variable can't do this: it
# only ever holds one value at a time, so there's no way to briefly show
# the "dimmed" state in between two polled snapshots -- deflisten's
# whole point is pushing as many intermediate frames as needed, on our
# own schedule, not eww's.
#
# "reveal" deliberately drives an *opacity* transition, not a `revealer`
# widget wrapping the label -- a `revealer` was tried first and collapses
# its child to zero height while hidden, which shrinks (then re-grows)
# the whole box every single line change. Opacity leaves the label's own
# row height untouched the entire time, so nothing above/below it moves.
#
# current_size scales the current line's own font down for long lines
# (see font_size_for) so a long line doesn't overflow the box's fixed
# width instead of needing the box to grow to fit it.
#
# Also emits "visible" (true only when MPD is actively [playing]), which
# eww.yuck uses to wrap the *entire* widget in an outer revealer -- NOT
# "eww close"/"eww open" on the window itself. Closing the window that
# way was tried first and is a trap: eww only keeps a deflisten script
# alive while some open window is actually using its variable, so a
# script that closes its own window gets killed the moment it does --
# nothing is left running to ever reopen it. Collapsing an outer
# revealer keeps the window (and this script) alive the whole time,
# avoiding that self-inflicted dead end entirely.

# font_size_for: the current line's font shrinks in three steps as its
# character count grows, so a long line stays inside the box's fixed
# 580px content width rather than needing the box to widen or the text
# to wrap. Thresholds picked for DejaVu Sans Mono at the base 15px size
# (~9px/char): 45 chars is where it starts getting close to the box's
# ~540px usable text width (580px minus the box's own 20px*2 padding).
font_size_for() {
    local len=$1
    if [ "$len" -gt 60 ]; then
        echo 11
    elif [ "$len" -gt 45 ]; then
        echo 13
    else
        echo 15
    fi
}

prev_current=""
while true; do
    if mpc status 2>/dev/null | grep -q '\[playing\]'; then
        playing="true"
    else
        playing="false"
    fi

    if [ "$playing" = "true" ]; then
        mpdtui -lyrics-line >/tmp/mpdtui-lyrics-line.txt 2>/dev/null
        above=$(sed -n '1p' /tmp/mpdtui-lyrics-line.txt)
        current=$(sed -n '2p' /tmp/mpdtui-lyrics-line.txt)
        below1=$(sed -n '3p' /tmp/mpdtui-lyrics-line.txt)
        below2=$(sed -n '4p' /tmp/mpdtui-lyrics-line.txt)
        current_size=$(font_size_for "${#current}")

        if [ "$current" != "$prev_current" ] && [ -n "$prev_current" ]; then
            # Fade out the old current line, keeping the old context
            jq -cn --argjson visible "$playing" --argjson size "$prev_size" --arg above "$prev_above" --arg current "$prev_current" --arg below1 "$prev_below1" --arg below2 "$prev_below2" \
                '{visible: $visible, reveal: false, current_size: $size, above: $above, current: $current, below1: $below1, below2: $below2}'
            sleep 0.3
        fi

        # Fade in the new current line with the new context
        jq -cn --argjson visible "$playing" --argjson size "$current_size" --arg above "$above" --arg current "$current" --arg below1 "$below1" --arg below2 "$below2" \
            '{visible: $visible, reveal: true, current_size: $size, above: $above, current: $current, below1: $below1, below2: $below2}'

        prev_current="$current"
        prev_above="$above"
        prev_below1="$below1"
        prev_below2="$below2"
        prev_size="$current_size"
    else
        jq -cn --argjson visible "$playing" \
            '{visible: $visible, reveal: true, current_size: 15, above: "", current: "", below1: "", below2: ""}'
        prev_current=""
    fi

    sleep 1
done
