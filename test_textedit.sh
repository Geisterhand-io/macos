#!/bin/bash

# Test script for Geisterhand - Opens TextEdit, writes text, maximizes, and saves
# Requires GeisterhandApp to be running on port 7676

API="http://127.0.0.1:7676"
FILENAME="geisterhand_test_$(date +%Y%m%d_%H%M%S).txt"

# Helper function for API calls
key_press() {
    local key="$1"
    local modifiers="$2"
    if [ -z "$modifiers" ]; then
        curl -s -X POST "$API/key" -H "Content-Type: application/json" -d "{\"key\": \"$key\"}"
    else
        curl -s -X POST "$API/key" -H "Content-Type: application/json" -d "{\"key\": \"$key\", \"modifiers\": $modifiers}"
    fi
    echo ""
}

type_text() {
    local text="$1"
    # Use jq to properly escape text for JSON
    local json_payload=$(jq -n --arg text "$text" '{text: $text}')
    curl -s -X POST "$API/type" -H "Content-Type: application/json" -d "$json_payload"
    echo ""
}

click_at() {
    local x="$1"
    local y="$2"
    curl -s -X POST "$API/click" -H "Content-Type: application/json" -d "{\"x\": $x, \"y\": $y}"
    echo ""
}

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "ERROR: jq is required. Install with: brew install jq"
    exit 1
fi

# Check if server is running
echo "Checking Geisterhand server status..."
STATUS=$(curl -s "$API/status")
if [ $? -ne 0 ]; then
    echo "ERROR: Cannot connect to Geisterhand server. Is GeisterhandApp running?"
    exit 1
fi
echo "Server is running!"
echo ""

# Step 1: Open Spotlight
echo "Opening Spotlight..."
key_press "space" '["cmd"]'
sleep 0.8

# Step 2: Type "TextEdit" and press Enter
echo "Launching TextEdit..."
type_text "TextEdit"
sleep 0.5
key_press "return"
sleep 2

# Step 3: Create new document
echo "Creating new document..."
key_press "n" '["cmd"]'
sleep 1

# Step 4: Type text
echo "Typing text..."
type_text "Hello from Geisterhand!

This is a test of the macOS automation tool.
Special characters work now: _-/~:()[]{}

It works!"
sleep 0.5

# Step 5: Maximize window (fullscreen toggle)
echo "Toggling fullscreen..."
key_press "f" '["cmd", "ctrl"]'
sleep 1.5

# Exit fullscreen
echo "Exiting fullscreen..."
key_press "f" '["cmd", "ctrl"]'
sleep 1

# Step 6: Save the file
echo "Opening save dialog..."
key_press "s" '["cmd"]'
sleep 1

# Go to folder dialog (Cmd+Shift+G)
echo "Opening Go to Folder..."
key_press "g" '["cmd", "shift"]'
sleep 0.8

# Type the Downloads path
echo "Typing path..."
type_text "~/Downloads"
sleep 0.3

# Press Enter to navigate to Downloads
echo "Navigating to Downloads..."
key_press "return"
sleep 1

# Now focus is back on Save As field - type the filename
echo "Typing filename in Save As field..."
# The Save As field should be focused, just type the filename
type_text "$FILENAME"
sleep 0.5

# Click the Save button (or press Enter)
echo "Saving..."
key_press "return"
sleep 1

# Close TextEdit
echo "Closing TextEdit..."
key_press "q" '["cmd"]'
sleep 0.5

echo ""
echo "Done! File should be saved as: ~/Downloads/$FILENAME"
