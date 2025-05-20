#!/bin/bash

if [[ "$OSTYPE" == "darwin"* ]]; then
    OPENCMD="open"
else
    OPENCMD="xdg-open"
fi

for arg in "$@"; do
    if [ -e "$arg" ] || [[ "$arg" =~ ^https?:// ]]; then
        "$OPENCMD" "$arg"
    else
        echo "Warning: '$arg' does not exist and is not a valid URL" >&2
    fi
done

