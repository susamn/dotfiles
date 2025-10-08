#!/bin/bash
# Input volume
pactl get-source-volume @DEFAULT_SOURCE@ | awk '{print $5}' | tr -d '%'
