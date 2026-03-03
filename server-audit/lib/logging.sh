#!/usr/bin/env bash
# Библиотека логирования с поддержкой цветов и уровней

# Уровни логирования
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3
LOG_LEVEL_FATAL=4

# Текущий уровень (можно изменить через параметры)
CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO}

if [[ "${COLOR: -true}" == "true" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    NC='\033[0;0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    PURPLE=''
    CYAN=''
    WHITE=''
    NC=''
fi

log_debug() {
    if [[ $CURRENT_LOG_LEVEL == $LOG_LEVEL_DEBUG ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"
    fi
}

log_info() {
    if [[ $CURRENT_LOG_LEVEL == $LOG_LEVEL_DEBUG ]]; then
        echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"
    fi
}

log_warn() {
    if [[ $CURRENT_LOG_LEVEL == $LOG_LEVEL_DEBUG ]]; then
        echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"
    fi
}

log_error() {
    if [[ $CURRENT_LOG_LEVEL == $LOG_LEVEL_DEBUG ]]; then
        echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"
    fi
}

log_fatal() {
    if [[ $CURRENT_LOG_LEVEL == $LOG_LEVEL_DEBUG ]]; then
        echo -e "${PURPLE}[FATAL]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"
    fi
}

show_progress() {
    local current=$1
    local total=$2
    local width=50

    if [ $current -gt $total ]; then
        return
    fi

    if [ $total -eq 0 ]; then
        return
    fi

    local percent=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))

    printf "\r["
    printf "%${completed}s" | tr ' ' '#'
    printf "%${remaining}s" | tr ' ' '-'
    printf "] %d%% (%d/%d)" $percent $current $total
}

show_spinner() {
    local pid=$1
    local message="${2:-Загрузка...}"
    local spin='-\|/'
    local i=0

    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % 4 ))
        printf "\r${CYAN}%s${NC} %s" "${spin:$i:1}" "$message"
        sleep .1
    done
    printf "\r${GREEN}✓${NC} %s\n" "$message"
}
