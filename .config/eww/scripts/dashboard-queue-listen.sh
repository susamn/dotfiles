#!/bin/bash
# Listens for pagination changes and queue changes, outputs queue JSON

prev_page=""
prev_pl=""

echo "[]"

while true; do
    page=$(eww get dashboard_queue_page 2>/dev/null || echo "0")
    pl_hash=$(mpc status | grep -oP 'playlist: \K[0-9]+' || mpc playlist | wc -c)

    if [ "$page" != "$prev_page" ] || [ "$pl_hash" != "$prev_pl" ]; then
        offset=$((page * 20))
        
        mpc playlist -f "%position%\t%title%\t%artist%" | tail -n +$((offset + 1)) | head -n 20 | \
        jq -R -s -c '
          [
            split("\n")[:-1][] | split("\t") | 
            {pos: .[0], title: .[1], artist: .[2]}
          ]'
        
        total=$(mpc playlist | wc -l)
        total_pages=$(( (total + 19) / 20 ))
        [ "$total_pages" -eq 0 ] && total_pages=1
        
        eww update dashboard_queue_total_pages="$total_pages" 2>/dev/null

        prev_page="$page"
        prev_pl="$pl_hash"
    fi
    sleep 0.5
done
