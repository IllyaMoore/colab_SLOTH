#!/bin/bash

# Google Colab Keep-Alive Script for Raspberry Pi
# Uses system utilities to simulate activity

set -e

# Configuration
COLAB_URL="${1:-https://colab.research.google.com/}"
INTERVAL="${2:-300}"  # default 5 minutes
LOG_FILE="colab_keepalive.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Dependency check
check_dependencies() {
    local missing_deps=()
    
    # Check xdotool (for simulating mouse/keyboard)
    if ! command -v xdotool &> /dev/null; then
        missing_deps+=("xdotool")
    fi
    
    # Check wmctrl (for window management)
    if ! command -v wmctrl &> /dev/null; then
        missing_deps+=("wmctrl")
    fi
    
    # Check curl
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log "ERROR: Missing dependencies: ${missing_deps[*]}"
        log "Install with: sudo apt-get install ${missing_deps[*]}"
        exit 1
    fi
    
    log "All dependencies installed ✓"
}

# Find browser window with Colab
find_colab_window() {
    # Extended browser window search
    local window_ids=$(wmctrl -l | grep -i -E "(colab|chrome|firefox|chromium|brave|edge|opera|browser)" | awk '{print $1}')
    
    # If nothing found by name, check active window
    if [ -z "$window_ids" ]; then
        log "No match by name, checking active window..."
        window_ids=$(xdotool getactivewindow 2>/dev/null)
    fi
    
    # If still nothing, check WM_CLASS
    if [ -z "$window_ids" ]; then
        log "Searching browsers by WM_CLASS..."
        window_ids=$(wmctrl -x -l | grep -i -E "(chrome|firefox|chromium|brave)" | awk '{print $1}' | head -1)
    fi
    
    if [ -z "$window_ids" ]; then
        log "WARNING: No browser windows found."
        log "Current windows:"
        wmctrl -l | head -5
        return 1
    fi
    
    # Return first window found
    echo "$window_ids" | head -1
}

# Activate browser window
activate_browser() {
    local window_id=$(find_colab_window)
    
    if [ -n "$window_id" ]; then
        wmctrl -i -a "$window_id" 2>/dev/null || true
        sleep 1
        log "Activated browser window: $window_id"
        return 0
    else
        log "Could not find browser window"
        return 1
    fi
}

# Simulate mouse movement
simulate_mouse() {
    # Get screen size
    local screen_info=$(xdotool getdisplaygeometry)
    local width=$(echo $screen_info | awk '{print $1}')
    local height=$(echo $screen_info | awk '{print $2}')
    
    # Generate random coordinates
    local x=$((RANDOM % (width - 200) + 100))
    local y=$((RANDOM % (height - 200) + 100))
    
    # Move mouse
    xdotool mousemove $x $y
    sleep 0.5
    
    # Sometimes click
    if [ $((RANDOM % 10)) -lt 2 ]; then
        xdotool click 1
        log "Mouse click at ($x, $y)"
    else
        log "Mouse move to ($x, $y)"
    fi
}

# Simulate scrolling
simulate_scroll() {
    local direction=$((RANDOM % 2))
    local scroll_amount=$((RANDOM % 3 + 1))
    
    if [ $direction -eq 0 ]; then
        xdotool key --repeat $scroll_amount "Page_Down"
        log "Scroll down ($scroll_amount times)"
    else
        xdotool key --repeat $scroll_amount "Page_Up" 
        log "Scroll up ($scroll_amount times)"
    fi
}

# Simulate keypress
simulate_keypress() {
    local keys=("space" "ctrl+Home" "ctrl+End" "F5")
    local random_key=${keys[$RANDOM % ${#keys[@]}]}
    
    # Rarely press keys
    if [ $((RANDOM % 20)) -lt 1 ]; then
        xdotool key "$random_key"
        log "Key pressed: $random_key"
    fi
}

# Prevent system sleep
prevent_sleep() {
    # Reset screensaver timer
    if command -v xset &> /dev/null; then
        xset s reset 2>/dev/null || true
    fi
    
    # Optionally use caffeinate
    if command -v caffeinate &> /dev/null; then
        caffeinate -u -t 1 2>/dev/null || true
    fi
}

# HTTP ping to Colab (if URL known)
http_ping() {
    if [[ "$COLAB_URL" == *"colab.research.google.com"* ]]; then
        curl -s -o /dev/null --max-time 10 \
             -H "User-Agent: Mozilla/5.0 (X11; Linux armv7l) AppleWebKit/537.36" \
             "$COLAB_URL" || true
        log "HTTP ping to Colab"
    fi
}

# Main activity simulation
simulate_activity() {
    local activities=("mouse" "scroll" "keypress" "http")
    local selected_activity=${activities[$RANDOM % ${#activities[@]}]}
    
    case $selected_activity in
        "mouse")
            simulate_mouse
            ;;
        "scroll") 
            simulate_scroll
            ;;
        "keypress")
            simulate_keypress
            ;;
        "http")
            http_ping
            ;;
    esac
    
    prevent_sleep
}

# Check if X server is running
check_display() {
    if [ -z "$DISPLAY" ]; then
        log "ERROR: DISPLAY not set. This script requires GUI."
        log "If using SSH, try: ssh -X user@raspberry_pi"
        exit 1
    fi
    
    if ! xdpyinfo &>/dev/null; then
        log "ERROR: Cannot connect to X server"
        exit 1
    fi
    
    log "X server connection OK ✓"
}

# Cleanup function
cleanup() {
    log "Termination signal received. Stopping script..."
    exit 0
}

# Main function
main() {
    log "=== Google Colab Keep-Alive Script (Bash) ==="
    log "URL: $COLAB_URL"
    log "Interval: $INTERVAL seconds"
    log "Log file: $LOG_FILE"
    
    # Setup signal handlers
    trap cleanup SIGINT SIGTERM
    
    # Checks
    check_display
    check_dependencies
    
    log "Starting activity simulation..."
    log "Make sure Google Colab is open in your browser!"
    
    # Main loop
    while true; do
        # Activate browser window
        activate_browser
        
        # Perform 2–3 random activities
        local num_activities=$((RANDOM % 2 + 2))
        for ((i=1; i<=num_activities; i++)); do
            simulate_activity
            sleep $((RANDOM % 3 + 1))  # Random 1–3 sec pause
        done
        
        # Wait until next loop
        local actual_interval=$((INTERVAL + RANDOM % 60 - 30))  # ±30 sec variation
        log "Waiting $actual_interval seconds until next activity..."
        sleep $actual_interval
    done
}

# Help function
usage() {
    echo "Usage: $0 [COLAB_URL] [INTERVAL]"
    echo ""
    echo "COLAB_URL  - Google Colab notebook URL (optional)"  
    echo "INTERVAL   - Interval between activities in seconds (default: 300)"
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "  $0 https://colab.research.google.com/drive/your-notebook-id"
    echo "  $0 https://colab.research.google.com/drive/your-notebook-id 180"
    echo ""
    echo "Dependencies (install with apt):"
    echo "  sudo apt-get install xdotool wmctrl curl"
}

# Param check
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

# Run
main "$@"
