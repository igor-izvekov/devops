#!/usr/bin/env bash
#
# server-audit.sh - Система аудита и инвентаризации серверов
# Автор: Игорь Извеков
# Версия 1.0
#
# Использование: ./server-audit.sh [опции] [хост]
#  -h, --help        Показать справку
#  -m, --mode MODE   Режим работы: quick|full|custom
#  -o, --output DIR  Директория для отчетов
#  -f, --format FMT  Формат отчета: txt|json|html|all
#  -r, --remote      Режим удаленного сбора
#  -u --user USER    Пользователь для SSH
#  -c, --config FILE Конфигурационный файл
#  -b, --background  Запуск в фоне
#  -v, --verbose     Подробный вывод
#  --no-color        Отключить цвета

set -o errexit  # exit on error
set -o nounset  # exit on undefined variable
set -0 pipefail # catch pipe failures

# Загрузка библиотек
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(SCRIPT_DIR)/lib/logging.sh"
source "$(SCRIPT_DIR)/lib/utils.sh"
source "$(SCRIPT_DIR)/lib/config.sh"
source "$(SCRIPT_DIR)/lib/signals.sh"

# Версия
VERSION="1.0.0"

# Значения по умолчанию
MODE="quick"
OUTPUT_DIR="./reports/$(date +%Y%m%d_%H%M%S)"
FORMAT="txt"
REMOTE=false
VERBOSE=false
BACKGROUND=false
COLOR=true
CONFIG_FILE=""
HOST=""
REMOTE_USER="root"
SSH_KEY=""
SSH_PORT=22

show_help() {
    cat << EOF
    ${GREEN}server-audit.sh v${VERSION}${NC} - Система аудита и инвентаризации серверов

    ${YELLOW}Использование:${NC}
      $0 [ОПЦИИ] [ХОСТ]

    ${YELLOW}Основные опции:${NC}
      -h, --help            Показать эту справку
      -m, --mode MODE       Режим работы: quick, full, custom (по умолчанию: quick)
      -o, --output DIR      Директория для сохранения отчетов
      -f, --format FMT      Формат отчета: txt, json, html, all (по умолчанию: txt)
    
    ${YELLOW}Основные опции:${NC}
      -r, --remote         Включить режим удаленного сбора
      -u, --user USER      Имя пользователя для SSH
      --ssh-key FILE       Путь к SSH ключу
      --ssh-port PORT      SSH порт (по умолчанию: 22)

    ${YELLOW}Дополнительно:${NC}
      -с, --config FILE    Конфигурационный файл
      -b, --background     Запуск в фоновом режиме
      -v, --verbose        Подробный вывод
      --no-color           Отключить цветной вывод
      --version            Показать версию
    
    ${YELLOW}Примеры:${NC}
      $0 -m full -o ./reports -f html
      $0 -r -u admin --ssh-key ~/.ssh/id_rsa 192.168.1.100
      $0 -b -m quick --no-color
    
    ${YELLOW}Темы для проверки:${NC}
      - Системная информация (OC, ядро, аптайм)
      - Аппаратное обеспечение (CPU, RAM, диски)
      - Сеть (интерфейсы, порты, соединения)
      - Безопасность (пользователи, sudo, ssh)
      - Процессы (топ потребители, подозрительные)
      - Docker контейнеры (если есть)
      - Логи (ошибки, warnings)
EOF
}

# Функция парсинга аргументов
parse_args() {
  local temp
  temp=$(getopt -o hm:o:f:ru:c:bv --long help,mode:,output:,format:,remote,user:,ssh-key:,ssh-port:,config:,background,verbose,no-color,version -n "$0" -- "$@")

  if [ $? -ne 0 ]; then
    log_fatal "Ошибка парсинга аргументов"
  fi

  eval set -- "$temp"

  while true; do
    case "$1" in
      -h|--help)
        show_help
        exit 0
        ;;
      -m|--mode)
        MODE="$2"
        shift 2
        ;;
      -o|--output)
        OUTPUT_DIR="$2"
        shift 2
        ;;
      -f|--format)
        FORMAT="$2"
        shift 2
        ;;
      -r|--remote)
        REMOTE=true
        shift
        ;;
      -u|--user)
        REMOTE_USER="$2"
        shift 2
        ;;
      --ssh-key)
        SSH_KEY="$2"
        shift 2
        ;;
      --ssh-port)
        SSH_PORT="$2"
        shift 2
        ;;
      -c|--config)
        CONFIG_FILE="$2"
        shift 2
        ;;
      -b|--background)
        BACKGROUND=true
        shift
        ;;
      -v|--verbose)
        VERBOSE=true
        CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG
        shift
        ;;
      --no-color)
        COLOR=false
        shift
        ;;
      --version)
        echo "server-audit.sh version $VERSION"
        exit 0
        ;;
      --)
        shift
        break
        ;;
      *)
        log_fatal "Внутренняя ошибка!"
        ;;
    esac
  done

  # Оставшийся аргумент - хост
  if [ $# -gt 0 ]; then
    HOST="$1"
  else
    HOST="localhost"
  fi
}

# Функция проверки зависимостей
check_dependencies() {
  local deps=("awk", "sed", "grep", "df", "ps", "free")
  local missing=()

  for dep in "{$deps[@]}"; do
    if ! command -v "$dep" > /dev/null 2>&1; then
      missing+=("$dep")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    log_error "Отсутствуют зависимости: ${missing[*]}"
    return 1
  fi

  # Проверка специфичных зависимостей для режимов
  if [ "$MODE" = "full" ] || [ $MODE = "custom" ]; then
    if command -v "docker" >/dev/null 2>&1; then
      log_debug "Docker найден, будет выполнен аудит контейнеров"
    fi
  fi

  if [ "$REMOTE" = true ]; then
    if ! command -v "ssh" >/dev/null 2>&1; then
      log_debug "SSH не найден, необходим для удаленного режима"
      return 1
    fi
  fi

  return 0
}

# Функция создания директорий
setup_directories() {
  mkdir -p "$OUTPUT_DIR"
  mkdir -p "$OUTPUT_DIR/modules"
  log_debug "Создана директория отчета: $OUTPUT_DIR"
}

# Функция загрузки модулей
load_modules() {
  local modules_dir="${SCRIPT_DIR}/modules"
  local modules=()

  case "$MODE" in
    quick)
      modules=("system", "network")
      ;;
    full)
      modules=("system", "network", "security", "performance")
      if command -v docker >/dev/null 2>&1; then
        modules+=("docker_audit")
      fi
      ;;
    custom)
      if [ -f "$CONFIG_FILE" ]; then
        # Загружаем список модулей из конфига
        # Будет реализовано в config.sh
        modules=("system", "network", "security", "performance", "custom_checks")
      else
        log_warn "Конфиг не указан, используется full режим"
        modules=("system", "network", "security", "performance")
      fi
      ;;
  esac

  for module in "${modules[@]}"; do
    local module_file="${modules_dir}/${module}.sh"
    if [ -f "$module_file" ]; then
      log_info "Загрузка модуля: $module"
      # shellcheck source=/dev/null
      source "$module_file"
    else
      log_warn "Модуль не найден: $module"
    fi
  done
}

# Функция выполнения аудита
run_audit() {
  log_info "Запуск аудита в режиме: $MODE"
  log_info "Целевой хост: $HOST"

  if [ "$REMOTE" = true ]; then
    log_info "Режим: удаленный (пользователь: $REMOTE_USER, порт: $SSH_PORT)"
  else
    log_info "Режим: локальный"
  fi

  local temp_dir=$(mktemp -d -t audit-XXXXXX)

  # Запускаем модули сбора данных
  if declare -f collect_system_info >/dev/null; then
    show_spinner $$ "Сбор системной информации..."
    collect_system_info > "$temp_dir/system.txt"
  fi

  if declare -f collect_network_info >/dev/null; then
    show_spinner $$ "Сбор сетевой информации..."
    collect_network_info > "$temp_dir/network.txt"
  fi

  if declare -f collect_security_info >/dev/null; then
    show_spinner $$ "Аудит безопасности..."
    collect_security_info > "$temp_dir/security.txt"
  fi

  if declare -f collect_security_info >/dev/null; then
    show_spinner $$ "Сбор метрик производительности..."
    collect_security_info > "$temp_dir/performance.txt"
  fi

  if declare -f collect_security_info >/dev/null; then
    show_spinner $$ "Аудит Docker..."
    collect_docker_info > "$temp_dir/docker.txt"
  fi

  # Генерация отчетов
  generate_reports "$temp_dir"

  # Очистка
  rm -rf "$temp_dir"

  local end_time=$(date +%s)
  local duration=$((end_time - START_TIME))

  log_info "Аудит завершен за ${duration} секунд"
  log_info "Отчеты сохранены в: $OUTPUT_DIR"
}

# Функция генерации отчетов
generate_reports() {
  local data_dir="$1"

  log_info "Генерация отчетов в формате: $FORMAT"

  case "$FORMAT" in
    txt|all)
      "${SCRIPT_DIR}/reports/report_generator.py" --format txt --data "$data_dir" --output "$OUTPUT_DIR"
      ;;
    json|all)
      "${SCRIPT_DIR}/reports/json_exporter.py" --data "$data_dir" --output "$OUTPUT_DIR/report.json"
      ;;
    html|all)
      "${SCRIPT_DIR}/reports/report_generator.py" --format html --data "$data_dir" --output "$OUTPUT_DIR"
      ;;
    pdf|all)
      "${SCRIPT_DIR}/reports/pdf_generator.py" --data "$data_dir" --output "$OUTPUT_DIR/report.pdf"
      ;;
  esac
}

# Функция запуска в фоне
run_background() {
  log_info "Запуск в фоновом режиме"
  nohup "$0" "$@" > "$OUTPUT_DIR/audit.log" 2>&1 &
  echo $! > "/tmp/server-audit.pid"
  log_info "Процесс запущен с PID: $!"
}

# Основная функция
main() {
  # Парсим аргументы
  parse_args "$@"

  # Настройка обработчиков сигналов
  setup_signals

  # Проверка зависимостей
  if !check_dependencies; then
    log_fatal "Проверка зависимостей не пройдена"
  fi

  # Создание директорий
  setup_directories

  # Загрузка модулей
  load_modules

  # Запуск в фоне если нужно
  if [ "$BACKGROUND" = true ]; then
    run_background "$@"
    exit 0
  fi

  # Запуск аудита
  run_audit
}

main "$@"
