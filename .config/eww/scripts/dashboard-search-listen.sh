#!/bin/bash
# Listens for eww variable changes and outputs JSON search results

prev_query=""
prev_filter=""

# Echo an empty array to start
echo "[]"

while true; do
    query=$(eww get dashboard_search_query 2>/dev/null)
    filter=$(eww get dashboard_search_filter 2>/dev/null || echo "track")

    if [ "$query" != "$prev_query" ] || [ "$filter" != "$prev_filter" ]; then
        if [ -z "$query" ]; then
            echo "[]"
        else
            if [ "$filter" = "track" ]; then
                mpc -f "%title%\t%artist%\t%file%" search any "$query" | head -n 20 | \
                jq -R -s -c '
                  [
                    split("\n")[:-1][] | split("\t") | 
                    {title: (if .[0] == "" then .[2] else .[0] end), artist: .[1], file: .[2]}
                  ]' || echo "[]"

            elif [ "$filter" = "playlist" ]; then
                mpc lsplaylists | grep -i "$query" | head -n 20 | \
                jq -R -s -c '
                  [
                    split("\n")[:-1][] | 
                    {title: ., artist: "Playlist", file: .}
                  ]' || echo "[]"

            elif [ "$filter" = "artist" ]; then
                mpc list artist | grep -i "$query" | head -n 20 | \
                jq -R -s -c '
                  [
                    split("\n")[:-1][] | 
                    {title: ., artist: "Artist", file: .}
                  ]' || echo "[]"
            fi
        fi
        
        prev_query="$query"
        prev_filter="$filter"
    fi
    sleep 0.5
done
