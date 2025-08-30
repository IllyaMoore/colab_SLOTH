
set -e

COLAB_URL="${1:-https://colab.research.google.com/}"
INTERVAL="${2:-300}"  # 5 хвилин за замовчуванням
LOG_FILE="colab_keepalive.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_dependencies() {
    local missing_deps=()
    
    if ! command -v xdotool &> /dev/null; then
        missing_deps+=("xdotool")
    fi
    
    if ! command -v wmctrl &> /dev/null; then
        missing_deps+=("wmctrl")
    fi
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log "${missing_deps[*]}"
        log "${missing_deps[*]}"
        exit 1
    fi
    
    log "✓"
}

find_colab_window() {
    local window_ids=$(wmctrl -l | grep -i -E "(colab|chrome|firefox|chromium)" | awk '{print $1}' | head -1)
    
    if [ -z "$window_ids" ]; then
        log "Window error, no browzer found"
        return 1
    fi
    
    echo "$window_ids"
}

activate_browser() {
    local window_id=$(find_colab_window)
    
    if [ -n "$window_id" ]; then
        wmctrl -i -a "$window_id" 2>/dev/null || true
        sleep 1
        log "browzer active: $window_id"
        return 0
    else
        log "window err"
        return 1
    fi
}

simulate_mouse() {
    local screen_info=$(xdotool getdisplaygeometry)
    local width=$(echo $screen_info | awk '{print $1}')
    local height=$(echo $screen_info | awk '{print $2}')
    
    local x=$((RANDOM % (width - 200) + 100))
    local y=$((RANDOM % (height - 200) + 100))
    
    xdotool mousemove $x $y
    sleep 0.5
    
    if [ $((RANDOM % 10)) -lt 2 ]; then
        xdotool click 1
        log "($x, $y)"
    else
        log "($x, $y)"
    fi
}

simulate_scroll() {
    local direction=$((RANDOM % 2))
    local scroll_amount=$((RANDOM % 3 + 1))
    
    if [ $direction -eq 0 ]; then
        xdotool key --repeat $scroll_amount "Page_Down"
        log "($scroll_amount)"
    else
        xdotool key --repeat $scroll_amount "Page_Up" 
        log "($scroll_amount)"
    fi
}

# Симуляція натискання клавіш
simulate_keypress() {
    local keys=("space" "ctrl+Home" "ctrl+End" "F5")
    local random_key=${keys[$RANDOM % ${#keys[@]}]}
    
    # Рідко натискаємо клавіші
    if [ $((RANDOM % 20)) -lt 1 ]; then
        xdotool key "$random_key"
        log "$random_key"
    fi
}

prevent_sleep() {
    if command -v xset &> /dev/null; then
        xset s reset 2>/dev/null || true
    fi
    
    if command -v caffeinate &> /dev/null; then
        caffeinate -u -t 1 2>/dev/null || true
    fi
}

http_ping() {
    if [[ "$COLAB_URL" == *"colab.research.google.com"* ]]; then
        curl -s -o /dev/null --max-time 10 \
             -H "User-Agent: Mozilla/5.0 (X11; Linux armv7l) AppleWebKit/537.36" \
             "$COLAB_URL" || true
        log "HTTP ping Colab"
    fi
}

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

# Перевірка, чи працює X server
check_display() {
    if [ -z "$DISPLAY" ]; then
        log " DISPLAY GUI."
        log " SSH"
        exit 1
    fi
    
    if ! xdpyinfo &>/dev/null; then
        log ""
        exit 1
    fi
    
    log "X server ОК ✓"
}

# Функція очищення при завершенні
cleanup() {
    log "stoped."
    exit 0
}

# Головна функція
main() {
    log "=== Google Colab Keep-Alive Script (Bash) ==="
    log "URL: $COLAB_URL"
    log "inter: $INTERVAL sec"
    log "logs: $LOG_FILE"
    
    # Встановлюємо обробники сигналів
    trap cleanup SIGINT SIGTERM
    
    # Перевірки
    check_display
    check_dependencies
    
    log "start..."
    
    # Основний цикл
    while true; do
        # Активуємо вікно браузера
        activate_browser
        
        # Виконуємо 2-3 різні активності
        local num_activities=$((RANDOM % 2 + 2))
        for ((i=1; i<=num_activities; i++)); do
            simulate_activity
            sleep $((RANDOM % 3 + 1))  # Випадкова пауза 1-3 сек
        done
        
        # Очікуємо до наступного циклу
        local actual_interval=$((INTERVAL + RANDOM % 60 - 30))  # ±30 сек варіації
        log "pouse $actual_interval sec for next act..."
        sleep $actual_interval
    done
}

# Функція допомоги
usage() {
    echo "usage: $0 [COLAB_URL] [INTERVAL]"
    echo ""
    echo ""  
    echo ""
    echo ""
    echo "samples:"
    echo "  $0"
    echo "  $0 https://colab.research.google.com/drive/your-notebook-id"
    echo "  $0 https://colab.research.google.com/drive/your-notebook-id 180"
    echo ""
    echo ""
    echo "  sudo apt-get install xdotool wmctrl curl"
}

# Перевірка параметрів
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

# Запуск
main "$@"