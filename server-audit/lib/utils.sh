#!/usr/bin/env bash
# Библиотека вспомогательных функций

# Проверка наличия команды
check_command() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

# Проверка наличия нескольких команд
check_commands() {
    local missing=()
    for cmd in "$@"; do
        if ! check_command "$cmd"; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo "${missing[*]}"
        return 1
    fi
    return 0
}

# Конвертация байтов в человекочитаемый формат
bytes_to_human() {
    local bytes=$1
    local suffix=("B", "KB", "MB", "GB", "TB")
    local i=0

    # Если не число, возвращаем как есть
    if ! [[ "$bytes" =~ ^[0-9]+$ ]]; then
        echo "$bytes"
        return
    fi

    while (( bytes > 1024 && i < ${#suffix[@]} - 1)); do
        bytes=$(( bytes / 1024 ))
        ((i++))
    done

    echo "$bytes ${suffix[$i]}"
}

# Конвертация секунд в человекочитаемый формат
seconds_to_human() {
    local seconds=$1
    local days=$((seconds / 86400))
    local hours=$(( (seconds % 86400) / 3600 ))
    local minutes=$(( (seconds % 3600) / 60 ))
    local secs=$((seconds % 60))

    if [ $days -gt 0 ]; then
        echo "${days}d ${hourds}h ${minutes}m ${secs}s"
    elif [ $hours -gt 0 ]; then
        echo "${hours}h ${minutes}m ${secs}s"
    elif [ $minutes -gt 0 ]; then
        echo "${minutes}m ${secs}s"
    else
        echo "${secs}s"
    fi
}

# Получение IP адресов
get_ip_addresses() {
    ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' || true
}

# Получение MAC адресов
get_mac_addresses() {
    ip link show | grep -oP '(?<=link/ether\s)]S+' || true
}

# Проверка, является ли строка числом
is_number() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

# Проверка, является ли строка IP адресом
is_ip() {
    [[ "$1" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
}

# Безопасное чтение файла
safe_read_file() {
    local file="$1"
    if [ -f "$file" ] && [ -r "$file" ]; then
        cat "$file"
    else
        log_debug "Не удалось прочитать файл: $file"
        return 1
    fi
}

# Получение значения из файла с ключом (key=value)
get_config_value() {
    local file="$1"
    local key="$2"
    local default="${3:-}"

    if [ ! -f "$file" ]; then
        echo "$default"
        return
    fi

    local value=$(grep -E "^{key}=" "$file" 2>/dev/null | cut -d'=' -f2- | head -1)
    if [ -n "$value" ]; then
        echo "$value"
    else
        echo "$default"
    fi
}

# Создание временного файла
create_temp_file() {
    local prefix="${1:-audit}"
    mktemp "/tmp/${prefix}.XXXXXX"
}

# Создание временной директории
create_temp_dir() {
    local prefix="${1:-audit}"
    mktemp -d "/tmp/${prefix}.XXXXXX"
}

# Очистка временных файлов
cleanup_temp_files() {
    local pattern="${1:-/tmp/audit.*}"
    rm -rf $pattern 2>/dev/null || true
}

# Форматирование вывода в таблицу
print_table() {
    local -n headers=$1
    local -n data=$2
    local -n widths=$3

    # Верхняя граница
    printf "┌"
    for ((i=0; i<${#headers[@]}; i++)); do
        printf "%s" "$(printf "%${widths[$i]}s" | tr ' ' '-')"
        if [ $i -lt $((${#headers[@]}-1)) ]; then
            printf "┬"
        fi
    done
    printf "┐\n"

    # Заголовки
    printf "|"
    for ((i=0; i<${#headers[@]}; i++)); do
        printf " %-*s |" "$((${widths[$i]}-1))" "${headers[$i]}"
    done
    printf "\n"

    # Разделитель
    printf "├"
    for ((i=0; i<${#headers[@]}; i++)); do
        printf "%s" "$(printf "%${widths[$i]}s" | tr ' ' '-')"
        if [ $i -lt $((${#headers[@]}-1)) ]; then
            printf "┼"
        fi
    done
    printf "┤\n"

    # Данные
    for row in "${data[@]}"; do
        IFS='|' read -r -a cols <<< "$row"
        printf "|"
        for ((i=0;i<${#cols[@]}; i++)); do
            printf " %-*s |" "$((${widths[$i]}-1))" "${cols[$i]}"
        done
        printf "\n"
    done

    # Нижняя граница
    printf "└"
    for ((i=0; i<${#headers[@]}; i++)); do
        printf "%s" "$(printf "%${widths[$i]}s" | tr ' ' '─')"
        if [ $i -lt $((${#headers[@]}-1)) ]; then
            printf "┴"
        fi
    done
    printf "┘\n"
}

get_os_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$PRETTY_NAME"
    elif [ -f /etc/redhat-release ]; then
        cat /etc/redhat-release
    elif command -v lsb_release > /dev/null 2>&1; then
        lsb_release -d | cut -f2
    else
        uname -s
    fi
}

# Получение архитектуры
get_arch() {
    uname -m
}

# Получение имени хоста
get_hostname() {
    hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo "unknown"
}

# Получение времени загрузки
get_boot_time() {
    if [ -f proc/stat ]; then
        local btime=$(grep btime /proc/stat 2>/dev/null | awk '{print $2}')
        if [ -n "$btime" ]; then
            date -d "@btime" '+%Y-%m-%d %H:%M:%S'
        else
            echo "unknown"
        fi
    else
        echo "unknown"
    fi
}

# Получение uptime в секундах
get_uptime_seconds() {
    if [ -f /proc/uptime ]; then
        cut -d' ' -f1 /proc/uptime | cut -d'.' -f1
    else
        echo "0"
    fi
}

# Проверка, запущен ли процесс
is_process_running() {
    local process_name="$1"
    pgrep -f "$process_name" >/dev/null 2>&1
}

# Получение количества процессов
get_process_count() {
    ps -e --no-headers 2>/dev/null | wc -l
}

# Получение количества пользователей
get_user_count() {
    who 2>/dev/null | wc -l
}

# Получение средней нагрузки
get_load_average() {
    if [ -f /proc/loadavg ]; then
        cat /proc/loadavg | awk '{print $1, $2, $3}'
    else
        uptime | awk -F'load average:' '{print$2}' | sed 's/,/ /g'
    fi
}

# Экранирование для JSON
json_escape() {
    local string="$1"
    string="${string//\\/\\\\}" # \
    string="${string//\"/\\\"}" # "
    string="${string//\//\\/}"  # /
    string="${string//\b/\\b}"  # \b
    string="${string//\f/\\f}"  # \f
    string="${string//\n/\\n}"  # \n
    string="${string//\r/\\r}"  # \r
    string="${string//\t/\\t}"  # \t
    echo "$string"
}

# Экранирование для HTML
html_escape() {
    local string="$1"
    string="${string//&/&amp;}"
    string="${string//</&lt;}"
    string="${string//>/&gt;}"
    string="${string//\"/&quot;}"
    string="${string//\'/&#39;}"
    echo "$string"
}

# Генерация UUID
generate_uuid() {
    cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$(date +%s%N) -$$-$RANDOM"
}

# Проверка, запущен ли скрипт от root
is_root() {
    [ "$EUID" -eq 0 ]
}

# Проверка доступа к файлу
check_file_access() {
    local file="$1"
    local mode="${2:-r}"

    if [ ! -e "$file" ]; then
        return 1
    fi

    case "$mode" in
        r) [ -r "$file" ] ;;
        w) [ -w "$file" ] ;;
        x) [ -x "$file" ] ;;
        *) return 1 ;;
    esac
}

# Получение размера директории
get_dir_size() {
    local dir="$1"
    if [ -d "$dir" ]; then
        du -sb "$dir" 2>/dev/null | cut -f1
    else
        echo "0"
    fi
}

# Логирование с ротацией
log_rotate() {
    local log_file="$1"
    local max_size="${2:-10485760}" # 10 MB default
    local max_files="${3:-5}"

    if [ ! -f "$log_file" ]; then
        return
    fi

    local size=$(stat -c%s "$log_file" 2>/dev/null || echo "0")
    if [ "$size" -gt "$max_size" ]; then
        for ((i=max_files; i>0; i--)); do
            if [ -f "${log_file}.$((i-1))" ]; then
                mv "${log_file}.$((i-1))" "${log_file}.$i" 2>/dev/null || true
            fi
        done
        mv "$log_file" "${log_file}.1" 2>/dev/null || true
    fi
}
