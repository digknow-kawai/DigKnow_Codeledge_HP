#!/usr/bin/env bash
set -euo pipefail

# 本番 codeledge.co から、ステージング stg.codeledge.co へ DB と uploads を反映する。
# 両者は同じサーバーの同じアカウント配下にあるため、ローカルのコピーで完結し
# SSH もネットワーク転送も使わない。themes と plugins は対象外。
# 本番への書き込みは一切行わない。
#
# 使い方: sync-prod-to-stg-codeledge.sh [退避先ディレクトリ] [保持する世代数]
#   退避先ディレクトリ: 既定は ~/work/codeledge-stg-db-backup
#   保持する世代数    : 既定は 7

if [ "$#" -gt 2 ]; then
  echo "usage: $0 [backup-dir] [retention-count]" >&2
  exit 1
fi

WP="/usr/local/bin/wp"

PROD_PATH="$HOME/domains/codeledge.co/public_html"
STG_PATH="$HOME/domains/stg.codeledge.co/public_html"
PROD_URL="https://codeledge.co"
STG_URL="https://stg.codeledge.co"

BACKUP_DIR="${1:-$HOME/work/codeledge-stg-db-backup}"
RETENTION="${2:-7}"

echo "==> 本番とステージングのテーブル接頭辞を読み取る"
PROD_PREFIX="$("$WP" --path="$PROD_PATH" config get table_prefix)"
STG_PREFIX="$("$WP" --path="$STG_PATH" config get table_prefix)"
echo "    本番: ${PROD_PREFIX}"
echo "    ステージング: ${STG_PREFIX}"

if [ "$PROD_PREFIX" != "$STG_PREFIX" ]; then
  echo "テーブル接頭辞が一致しない (本番: ${PROD_PREFIX}、ステージング: ${STG_PREFIX})" >&2
  echo "ステージング側を本番に合わせる移行が別途要る。反映は行わずに終了する" >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"
STG_BACKUP_FILE="${BACKUP_DIR}/stg-db-$(date +%Y%m%d).sql"

echo "==> ステージングの DB を退避する: ${STG_BACKUP_FILE}"
"$WP" --path="$STG_PATH" db export "$STG_BACKUP_FILE"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
PROD_DUMP="${WORK_DIR}/prod.sql"

echo "==> 本番の DB をダンプする"
"$WP" --path="$PROD_PATH" db export "$PROD_DUMP"

echo "==> ステージングの DB へ本番のダンプを取り込む"
"$WP" --path="$STG_PATH" db import "$PROD_DUMP"

echo "==> ステージングで URL を置換する"
"$WP" --path="$STG_PATH" search-replace "$PROD_URL" "$STG_URL"

echo "==> 本番の uploads をステージングへ同期する (本番に無いファイルは削除する)"
rsync -a --delete \
  "${PROD_PATH}/wp-content/uploads/" \
  "${STG_PATH}/wp-content/uploads/"

echo "==> 外部へ出る経路を止める"
# 入っていないプラグインを渡すと wp plugin deactivate が失敗するため、有無を確かめてから止める
for PLUGIN in google-site-kit wp-mail-smtp; do
  if "$WP" --path="$STG_PATH" plugin is-installed "$PLUGIN"; then
    "$WP" --path="$STG_PATH" plugin deactivate "$PLUGIN"
  fi
done
if "$WP" --path="$STG_PATH" plugin is-installed seo-simple-pack; then
  "$WP" --path="$STG_PATH" option patch update ssp_settings google_g_id '' || true
  "$WP" --path="$STG_PATH" option patch update ssp_settings google_ua_id '' || true
  "$WP" --path="$STG_PATH" option patch update ssp_settings webmaster_google '' || true
fi

echo "==> 退避したダンプのうち古い世代を消す (保持世代数: ${RETENTION})"
shopt -s nullglob
BACKUPS=("${BACKUP_DIR}"/stg-db-*.sql)
shopt -u nullglob
COUNT=${#BACKUPS[@]}
if [ "$COUNT" -gt "$RETENTION" ]; then
  DELETE_COUNT=$((COUNT - RETENTION))
  for ((i = 0; i < DELETE_COUNT; i++)); do
    echo "    削除: ${BACKUPS[$i]}"
    rm -f "${BACKUPS[$i]}"
  done
fi

echo "==> 完了"
