# infra-monitoring-project

Учебный DevOps-проект: мониторинг доступности API, анализ логов и контейнеризированный стек.

## Состав проекта

| Файл | Назначение |
|---|---|
| `check_api.sh` | Проверка доступности API по HTTP-коду |
| `analyze_logs.sh` | Генерация `access.log` и анализ |
| `docker-compose.yml` | Сервисы `api` (hashicorp/http-echo) и `proxy` (nginx:alpine) |
| `nginx/default.conf` | Конфигурация reverse proxy |
| `.github/workflows/ci.yml` | CI: проверка синтаксиса и тест скриптов на каждый PR |
| `docs/traffic_dump.pcapng` | Дамп трафика |

## Требования
Linux / WSL2 (Ubuntu), `bash`, `curl`, `git`, Docker + Docker Compose.

## Быстрый старт

```bash
git clone https://github.com/<USER>/infra-monitoring-project.git
cd infra-monitoring-project
chmod +x check_api.sh analyze_logs.sh
```

### check_api.sh
```bash
./check_api.sh https://httpbin.org/status/200   # "API доступен", код возврата 0
./check_api.sh https://httpbin.org/status/503   # "API недоступен, код ответа: 503", код возврата 1
./check_api.sh not-a-url                        # ошибка URL, код возврата 1
echo $?                                         # код возврата последней команды
```

### analyze_logs.sh
```bash
./analyze_logs.sh                  
./analyze_logs.sh /tmp/test.log 1000
```
Выводит: общее число запросов, топ 3 IP, количество ответов 4xx и 5xx.

### Docker Compose
```bash
docker-compose up -d
docker-compose ps
curl http://localhost:80
./check_api.sh http://localhost
docker-compose down
```
Контейнеры работают во внутренней сети `monitoring-net`. Наружу опубликован только порт 80 прокси. Сервис `api` (порт 8080) доступен только внутри сети; nginx обращается к нему по DNS-имени `api`.

## CI/CD
При создании Pull Request в `main` GitHub Actions выполняет:
1. `bash -n check_api.sh` и `bash -n analyze_logs.sh`;
2. `./check_api.sh https://httpbin.org/status/200` (ожидается код возврата 0);
3. негативные тесты, тест `analyze_logs.sh` и валидацию `docker-compose.yml`.

## Безопасная передача проекта на удаленный сервер (SSH/SCP)

### 1. Генерация SSH-ключей
```bash
ssh-keygen -t ed25519 -C "<user сервера>@infra-monitoring" -f ~/.ssh/id_ed25519_<user сервера>
chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_ed25519_<user сервера>
```

### 2. Копирование публичного ключа на сервер
```bash
ssh-copy-id -i ~/.ssh/id_ed25519_<user сервера>.pub <user сервера>@<IP сервера>
ssh -i ~/.ssh/id_ed25519_<user сервера> <user сервера>@<IP сервера>
```
Псевдоним в `~/.ssh/config`:
```
Host infra-server
    HostName <IP сервера>
    User <user сервера>
    IdentityFile ~/.ssh/id_ed25519_<user сервера>
```
После этого достаточно `ssh infra-server`.

### 3. Передача проекта

**Вариант A: архив и scp**
```bash
git archive --format=tar.gz --prefix=infra-monitoring/ -o /tmp/infra-monitoring.tar.gz HEAD
sha256sum /tmp/infra-monitoring.tar.gz
scp /tmp/infra-monitoring.tar.gz infra-server:/tmp/
ssh infra-server "mkdir -p ~/app && tar xzf /tmp/infra-monitoring.tar.gz -C ~/app && sha256sum /tmp/infra-monitoring.tar.gz"
```

**Вариант B: tar через ssh**
```bash
tar czf - --exclude='.git' --exclude='*.log' . | ssh infra-server "mkdir -p ~/app/infra-monitoring && tar xzf - -C ~/app/infra-monitoring"
```

**Вариант C: rsync по SSH**
```bash
rsync -avz --delete --exclude='.git' --exclude='*.log' -e ssh ./ infra-server:~/app/infra-monitoring/
```

### 4. Запуск на сервере
```bash
ssh infra-server "cd ~/app/infra-monitoring && chmod +x *.sh && docker compose up -d && docker compose ps"
ssh infra-server "cd ~/app/infra-monitoring && ./check_api.sh http://localhost"
```
