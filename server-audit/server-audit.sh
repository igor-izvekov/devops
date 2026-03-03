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