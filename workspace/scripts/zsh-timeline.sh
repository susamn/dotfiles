#!/bin/bash

# Script to visualize .zshrc load times
DATA_FILE="$HOME/.local/data/zsh-run/data.timeline"
VERBOSE=false

# Parse arguments
while getopts "v" opt; do
    case $opt in
        v) VERBOSE=true ;;
        *) echo "Usage: $0 [-v]"; exit 1 ;;
    esac
done

# Check if data file exists
if [[ ! -f "$DATA_FILE" ]]; then
    echo "No data available yet. Start a new terminal session to begin tracking."
    exit 0
fi

# Check if file is empty
if [[ ! -s "$DATA_FILE" ]]; then
    echo "No data available yet. Start a new terminal session to begin tracking."
    exit 0
fi

# Calculate statistics using awk
read MAX_TIME MIN_TIME AVG_TIME COUNT < <(awk -F'|' '
    BEGIN { max=0; min=999999; sum=0; count=0 }
    NF >= 3 && $3 != "" {
        time = $3 + 0
        if (time > max) max = time
        if (time < min) min = time
        sum += time
        count++
    }
    END {
        avg = (count > 0) ? sum/count : 0
        printf "%.10f %.10f %.3f %d", max, min, avg, count
    }
' "$DATA_FILE")

if [[ "$VERBOSE" == false ]]; then
    # Simple mode: just show spark graph
    if ! command -v spark &> /dev/null; then
        echo "Note: 'spark' command not found. Install via 'brew install spark' or falling back to verbose mode."
        echo ""
        VERBOSE=true
    else
        echo ""
        echo "=== .zshrc Load Time Timeline ==="
        echo ""

        # Extract load times and pass to spark
        LOAD_TIMES=$(awk -F'|' 'NF >= 3 && $3 != "" {print $3}' "$DATA_FILE")
        echo "$LOAD_TIMES" | spark

        echo ""
        echo "Statistics:"
        echo "  Total measurements: $COUNT"
        printf "  Average load time:  %.3fs\n" "$AVG_TIME"
        printf "  Minimum load time:  %.3fs\n" "$MIN_TIME"
        printf "  Maximum load time:  %.3fs\n" "$MAX_TIME"
        echo ""
    fi
fi

if [[ "$VERBOSE" == true ]]; then
    # Verbose mode: show detailed timeline with | character
    # Get terminal width for dynamic sizing
    TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
    GRAPH_WIDTH=$((TERM_WIDTH - 35))
    [[ $GRAPH_WIDTH -lt 20 ]] && GRAPH_WIDTH=20

    # Display header
    echo ""
    echo "=== .zshrc Load Time Timeline ==="
    echo ""
    printf "%-19s  %-8s  %s\n" "Timestamp" "Time(s)" "Graph"
    printf "%-19s  %-8s  %s\n" "-------------------" "--------" "$(printf '%*s' $GRAPH_WIDTH '' | tr ' ' '-')"

    # Read and display data with graph
    while IFS='|' read -r timestamp datetime loadtime; do
        [[ -z "$loadtime" ]] && continue

        # Calculate bar length using awk
        BAR_LENGTH=$(awk -v time="$loadtime" -v max="$MAX_TIME" -v width="$GRAPH_WIDTH" '
            BEGIN {
                if (max > 0) {
                    len = int((time / max) * width)
                    print (len < 1) ? 1 : len
                } else {
                    print 1
                }
            }
        ')

        # Create bar with | character
        BAR=$(printf '%*s' "$BAR_LENGTH" '' | tr ' ' '|')

        # Extract time portion (HH:MM:SS)
        TIME_PART=$(echo "$datetime" | awk '{print $2}')

        # Print row
        printf "%-19s  %7.3fs  %s\n" "$TIME_PART" "$loadtime" "$BAR"
    done < "$DATA_FILE"

    # Display statistics
    echo ""
    echo "Statistics:"
    echo "  Total measurements: $COUNT"
    printf "  Average load time:  %.3fs\n" "$AVG_TIME"
    printf "  Minimum load time:  %.3fs\n" "$MIN_TIME"
    printf "  Maximum load time:  %.3fs\n" "$MAX_TIME"
    echo ""
fi
