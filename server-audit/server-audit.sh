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
