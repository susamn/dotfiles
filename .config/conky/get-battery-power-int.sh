#!/bin/bash
awk '{printf "%d", $1/1000000}' /sys/class/power_supply/BAT0/power_now
