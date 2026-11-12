#!/usr/bin/env bash

EXPECTED_CODE=200
TIMEOUT=10
URL_REGEX='^https?://[^[:space:]/]+(/[^[:space:]]*)?$'

usage() {
    echo "Использование: $0 <URL>" >&2
    echo "Пример:        $0 https://httpbin.org/status/200" >&2
}

if [[ $# -ne 1 ]]; then
    echo "Ошибка: нужно передать ровно один аргумент (URL)." >&2
    usage
    exit 1
fi

URL="$1"

if ! [[ "$URL" =~ $URL_REGEX ]]; then
    echo "Ошибка: некорректный URL: '$URL' (ожидается http:// или https://)" >&2
    exit 1
fi

HTTP_CODE=$(curl --silent --output /dev/null --write-out '%{http_code}' \
                 --max-time "$TIMEOUT" "$URL")
CURL_RC=$?

if [[ $CURL_RC -ne 0 ]]; then
    echo "API недоступен, код ответа: ${HTTP_CODE:-000} (ошибка curl: $CURL_RC)"
    exit 1
fi

if [[ "$HTTP_CODE" -eq "$EXPECTED_CODE" ]]; then
    echo "API доступен"
    exit 0
else
    echo "API недоступен, код ответа: $HTTP_CODE"
    exit 1
fi
