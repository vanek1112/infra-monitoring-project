#!/usr/bin/env bash

LOG_FILE="${1:-access.log}"
LINES="${2:-500}"

if ! [[ "$LINES" =~ ^[0-9]+$ ]] || (( LINES < 300 )); then
    echo "Ошибка: число строк должно быть целым числом >= 300" >&2
    exit 1
fi

IP_REGEX='^([0-9]{1,3}\.){3}[0-9]{1,3}'
LINE_REGEX='^([0-9]{1,3}\.){3}[0-9]{1,3} - - \[[^]]+\] "[A-Z]+ [^ ]+ HTTP/[0-9.]+" [0-9]{3}$'

IPS=(192.168.1.10 192.168.1.10 192.168.1.10 192.168.1.10 192.168.1.10
     10.0.0.5 10.0.0.5 10.0.0.5 10.0.0.5
     172.16.0.8 172.16.0.8 172.16.0.8
     203.0.113.42 198.51.100.7 192.168.1.25 10.0.0.77)
METHODS=(GET GET GET GET POST POST PUT DELETE)
ENDPOINTS=(/api/users /api/users /api/users /api/login /api/login
           /api/orders /api/products /api/health /admin /api/orders/42)
CODES=(200 200 200 200 200 200 201 301 400 401 401 403 404 404 500 502 503)

generate_log() {
    local i t ip method endpoint code
    for (( i = 0; i < LINES; i++ )); do
        ip=${IPS[RANDOM % ${#IPS[@]}]}
        method=${METHODS[RANDOM % ${#METHODS[@]}]}
        endpoint=${ENDPOINTS[RANDOM % ${#ENDPOINTS[@]}]}
        code=${CODES[RANDOM % ${#CODES[@]}]}
        t=$(( (10 * 3600 + i * 7) % 86400 ))
        printf '%s - - [15/Aug/2026:%02d:%02d:%02d] "%s %s HTTP/1.1" %s\n' \
            "$ip" $(( t / 3600 )) $(( t % 3600 / 60 )) $(( t % 60 )) \
            "$method" "$endpoint" "$code"
    done > "$LOG_FILE"
}

echo "Генерация тестового лога: $LOG_FILE ($LINES строк)"
generate_log
echo "Первые 3 строки:"
head -n 3 "$LOG_FILE"
echo

echo "Анализ лога"

TOTAL=$(grep -cE "$LINE_REGEX" "$LOG_FILE")
echo "Общее количество запросов: $TOTAL"
echo

echo "Топ 3 IP-адреса:"
grep -oE "$IP_REGEX" "$LOG_FILE" \
    | sort | uniq -c | sort -rn | head -n 3 \
    | awk '{ printf "  %d) %-15s - %d запросов\n", NR, $2, $1 }'
echo

echo "Ошибочные ответы:"
awk '
    $NF ~ /^4[0-9][0-9]$/ { c4++ }
    $NF ~ /^5[0-9][0-9]$/ { c5++ }
    END {
        printf "  4xx (ошибки клиента): %d\n", c4 + 0
        printf "  5xx (ошибки сервера): %d\n", c5 + 0
    }' "$LOG_FILE"
echo

echo "Распределение по кодам ответа:"
awk '{ print $NF }' "$LOG_FILE" | sort | uniq -c | sort -k2,2n \
    | awk '{ printf "  %s - %d\n", $2, $1 }'
echo

echo "Топ 3 запроса:"
grep -oE '"[A-Z]+ [^ ]+' "$LOG_FILE" | sed 's/^"//' \
    | sort | uniq -c | sort -rn | head -n 3 \
    | awk '{ printf "  %d) %s %s - %d раз\n", NR, $2, $3, $1 }'
