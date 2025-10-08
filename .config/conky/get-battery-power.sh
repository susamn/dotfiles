#!/bin/bash
awk '{printf "%.2fW", $1/1000000}' /sys/class/power_supply/BAT0/power_now
