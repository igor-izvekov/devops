#!/usr/bin/env bash
# Библиотека для работы с конфигурационными файлами

# Глобальная переменная для хранения конфигурации
declare -A CONFIG 

# Загрузка конфигурации из файла
load_config() {
    local config_file="$1"

    if [ ! -f "$config_file" ]; then
        log_warn "Конфигурационный файл не найден: $config_file"
        return 1
    fi

    log_debug "Загрузка конфигурации из: $config_file"

    local line_num=0
    while IFS= read -r line || [ -n "$line" ]; do
        ((line_num++))

        # Удаляем комментарии и пробелы
        line=$(echo "$line" | sed -e 's/#.*//' -e 's/^[[:space]]*//' -e 's/[[:space:]]*$//')

        # Пропускаем пустые строки
        if [ -z "$line" ]; then
            continue
        fi

        # Проверяем формат ключ=значение
        if [[ "$line" =~ ^[a-zA-Z_][a-zA-Z0-9_.-]*=.*$ ]]; then
            local key="${line%%=*}"
            local value="${line#*=}"

            # Убираем кавычки, если есть
            value=$(echo "$value" | sed -e "s/^['\"]//" -e "s/['\"]$//")

            # Сохраняем в ассоциативный массив
            CONFIG["$key"]="$value"

            log_debug "   config: $key = $value"
        else
            log_warn "Неверный формат в конфиге (строка $line_num): $line"
        fi
    done < "$config_file"

    log_debug "Загружено ${#CONFIG[@]} параметров"
}

# Получение значения из конфигурации
get_config() {
    local key="$1"
    local default="${2:-}"

    # Сначалаа проверяем переменную окружения AUDIT_*
    local env_key="AUDIT_${key}"
    if [ -n "${!env_key:-}" ]; then
        echo "${!env_key}"
        return
    fi

    # Затем проверяем конфиг
    if [ -n "${CONFIG[$key]:-}" ]; then
        echo "${CONFIG[$key]}"
        return
    fi

    # Иначе возвращаем значение по умолчанию
    echo "$default"
}

# Получение булевого значения
get_config_bool() {
    local key="$1"
    local default="${2:-false}"

    local value=$(get_config "$key" "$default")
    # TODO...
}