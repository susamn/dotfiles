#!/bin/bash

killall -9 waybar
waybar -c ~/.config/waybar/config.jsonc -s ~/.config/waybar/style.css &
