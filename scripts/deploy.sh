#!/usr/bin/env bash
set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
REPO_ROOT="$(git rev-parse --show-toplevel)"
LOCAL_DIR="${REPO_ROOT}/site/"

DRY_RUN=""
if [[ $# -gt 0 ]]; then
  if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN="--dry-run"
  else
    echo "Ошибка: неизвестный аргумент '$1'" >&2
    echo "Использование: $0 [--dry-run]" >&2
    exit 1
  fi
fi

if [[ ! -f "${LOCAL_DIR}index.html" ]]; then
  echo "Ошибка: обязательный файл ${LOCAL_DIR}index.html не найден!" >&2
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Ошибка: в репозитории имеются незафиксированные изменения!" >&2
  exit 1
fi

SSH_CMD="ssh -o BatchMode=yes -o ConnectTimeout=5"

echo "=== Выполняется синхронизация файлов ==="
rsync -avz --delete --chmod=D755,F644 ${DRY_RUN} -e "${SSH_CMD}" "${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}/"

if [[ -n "${DRY_RUN}" ]]; then
  echo "Режим --dry-run: синхронизация не производилась, состояние сервера не изменено."
  exit 0
fi

echo "=== Проверка доступности ресурса ==="
if ! curl -fsS --cacert "${CA_CERT}" "${SITE_URL}" > /dev/null; then
  echo "Ошибка: веб-ресурс ${SITE_URL} недоступен или проверка сертификата завершилась сбоем!" >&2
  exit 1
fi

COMMIT_HASH="$(git rev-parse --short HEAD)"
echo "Деплой успешно завершен. Версия коммита: ${COMMIT_HASH}"
exit 0