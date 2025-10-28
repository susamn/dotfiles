#!/bin/bash
# Simple keyboard capture script
# Press Ctrl+C to exit

echo "=========================================="
echo "Keyboard Event Listener"
echo "=========================================="
echo "Press any key to see what was pressed."
echo "Press Ctrl+C to exit."
echo ""

# Save terminal settings
old_tty_settings=$(stty -g)

# Set terminal to raw mode to capture individual keypresses
stty -icanon -echo time 0 min 0

# Cleanup function to restore terminal settings
cleanup() {
    echo ""
    echo "Restoring terminal settings..."
    stty "$old_tty_settings"
    exit 0
}

# Trap Ctrl+C and other exit signals
trap cleanup INT TERM EXIT

# Main loop
while true; do
    # Read single character
    char=$(dd bs=1 count=1 2>/dev/null)

    if [ -n "$char" ]; then
        # Get the ASCII/hex value
        hex_value=$(printf "%s" "$char" | od -An -tx1 | tr -d ' \n')
        ascii_value=$(printf "%s" "$char" | od -An -td1 | tr -d ' \n')

        # Handle special cases
        case "$ascii_value" in
            3)
                echo "Key: Ctrl+C (ASCII: $ascii_value, HEX: 0x$hex_value)"
                cleanup
                ;;
            9)
                echo "Key: Tab (ASCII: $ascii_value, HEX: 0x$hex_value)"
                ;;
            10|13)
                echo "Key: Enter (ASCII: $ascii_value, HEX: 0x$hex_value)"
                ;;
            27)
                echo "Key: ESC or Arrow/Special key (ASCII: $ascii_value, HEX: 0x$hex_value)"
                ;;
            32)
                echo "Key: Space (ASCII: $ascii_value, HEX: 0x$hex_value)"
                ;;
            127)
                echo "Key: Backspace (ASCII: $ascii_value, HEX: 0x$hex_value)"
                ;;
            *)
                if [ "$ascii_value" -ge 32 ] && [ "$ascii_value" -le 126 ]; then
                    echo "Key: '$char' (ASCII: $ascii_value, HEX: 0x$hex_value)"
                else
                    echo "Key: [Special] (ASCII: $ascii_value, HEX: 0x$hex_value)"
                fi
                ;;
        esac
    fi

    # Small sleep to prevent high CPU usage
    sleep 0.01
done
