#!/bin/bash
VERSION="2.0.0"

# Загружаем библиотеку с настройками и функциями
SCRIPT_LIB="$(dirname "$0")/pg_dump.lib"
if [[ ! -f "$SCRIPT_LIB" ]]; then
    echo -e "\e[31mОшибка: файл библиотеки $SCRIPT_LIB не найден\e[0m"
    exit 1
fi
source "$SCRIPT_LIB"

# Определяем функции перед их вызовом!

# Автоматический режим — бэкап баз из pg_dump.conf
do_auto_backup() {
    rotate_logs
    # Загружаем список баз данных для создания дампа
    if [[ ! -f "$SCRIPT_CONF" ]]; then
        log "❌ Конфигурационный файл не найден: $SCRIPT_CONF"
        send_telegram "❌ Конфигурационный файл не найден: \`$SCRIPT_CONF\`"
        exit 1
    fi
    mapfile -t BASES < "$SCRIPT_CONF"
    # Запускаем задачу
    for DB_NAME in "${BASES[@]}"; do
        log "Резервное копирование базы: $DB_NAME"
        # Определяем путь для сохранения дампа базы
        BACKUP_PATH="$BACKUP_DIRECTORY_AUTO/$DATE/$DB_NAME"
        # Проверка и создание каталога
        if [ -d "$BACKUP_PATH" ]; then
            log "⚠️ Каталог резервной копии для $DB_NAME уже существует. Пропускаем."
            send_telegram "⚠️ Пропущено резервное копирование базы \`$DB_NAME\` — каталог уже существует."
            continue
        fi
        # Делаем задачу
        if run_backup_for "$DB_NAME" "$BACKUP_PATH"; then
            log "✅ Резервное копирование базы $DB_NAME успешно завершено."
            send_telegram "✅ Резервная копия базы \`$DB_NAME\` выполнена успешно."
        else
            log "❌ Ошибка резервного копирования базы $DB_NAME!"
            send_telegram "❌ Ошибка при резервном копировании базы \`$DB_NAME\`!"
        fi
    done
}

# Ручной режим — выбор базы из списка по индексу
do_manual_backup() {
    rotate_logs
    # Получаем отсортированный список баз (исключая шаблонные)
    DB_LIST=$(psql $DB_CONNECT $DB_BASES_QUERY -At -c "SELECT datname FROM pg_database WHERE NOT datistemplate ORDER BY datname;")
    # Преобразуем в массив
    IFS=$'\n' read -r -d '' -a DB_ARRAY < <(printf '%s\0' "$DB_LIST")
    # Вывод списка баз с индексами в вертикальные 2 колонки с отступом между ними
    echo -e "\e[32m\nДоступные базы данных:\e[0m"
    rows=$(( (${#DB_ARRAY[@]} + columns - 1) / columns ))
    for ((i=0; i<rows; i++)); do
        line=""
        for ((j=0; j<columns; j++)); do
            index=$((i + j * rows))
            if [ $index -lt ${#DB_ARRAY[@]} ]; then
                entry=$(printf "\e[33m[%2d] %-20s\e[0m" "$index" "${DB_ARRAY[$index]}")
                line+="$entry$spacing"
            fi
        done
        echo -e "$line"
    done
    # Ввод номера базы из индекса
    echo -e "\e[32m\nВведите номер базы данных для резервного копирования:\e[0m"
    read -r -p "> " DB_INDEX
    # Проверка индекса
    if ! [[ "$DB_INDEX" =~ ^[0-9]+$ ]] || [[ -z "${DB_ARRAY[$DB_INDEX]}" ]]; then
        echo -e "\e[31m\nОшибка: неправильный индекс!\e[0m"
        exit 1
    fi
    # Подтверждение
    DB_NAME="${DB_ARRAY[$DB_INDEX]}"
    echo -e "\e[32m\nВы выбрали базу данных: \e[33m$DB_NAME\e[0m"
    read -r -p "Вы хотите продолжить? [y/N] " response
    [[ ! "$response" =~ ^[Yy]$ ]] && echo "OK. Выход." && exit 0
    # Определяем путь для сохранения дампа базы
    BACKUP_PATH="$BACKUP_DIRECTORY_MANUAL/$DB_NAME/$DATE/$TIME"
    # Проверка и создание каталога
    if [ ! -d "$BACKUP_PATH" ]; then
        mkdir -p "$BACKUP_PATH"
    else
        echo "Backup overwrite attempt detected. Exiting."
        exit 1
    fi
    # Выполняем дамп базы
    if run_backup_for "$DB_NAME" "$BACKUP_PATH"; then
        log "✅ Резервное копирование базы $DB_NAME успешно завершено."
        send_telegram "✅ Ручное резервное копирование базы \`$DB_NAME\` выполнено успешно."
    else
        log "❌ Ошибка резервного копирования базы $DB_NAME!"
        send_telegram "❌ Ошибка при ручном резервном копировании базы \`$DB_NAME\`!"
        exit 1
    fi
}

# Вывод справки
print_help() {
    echo "PostgreSQL Base Backup script"
    echo ""
    echo "Usage: $0 [--manual|--help|--version]"
    echo ""
    echo "Запуск без параметров запустит резервное копирование баз из pg_dump.conf"
    echo ""
    echo "  --manual      Показать список баз и вручную выбрать для резервного копирования"
    echo "  --help        Показать это сообщение"
    echo "  --version     Показать версию скрипта"
    exit 0
}

# Вывод версии скрипта
print_version() {
    echo "Script version $VERSION by Eugene Gashinov"
    exit 0
}

# Обработка параметров командной строки
case "$1" in
    --manual)
        do_manual_backup
        ;;
    --help)
        print_help
        ;;
    --version)
        print_version
        ;;
    "")
        do_auto_backup
        ;;
    *)
        echo -e "\e[31mНеизвестный параметр: $1\e[0m"
        print_help
        ;;
esac
