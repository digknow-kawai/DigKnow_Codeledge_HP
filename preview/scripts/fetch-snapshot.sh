#!/usr/bin/env bash
set -euo pipefail

# ステージング stg.codeledge.co から preview 用のスナップショットを作る。ローカルでも日次のワークフローでも同じものを使う。
# コアサーバーへの書き込みは一切行わない。実行するのは grep、wp db export、rsync の取得方向のみ。
#
# 使い方: fetch-snapshot.sh [出力先ディレクトリ]
#   出力先ディレクトリ: 既定は $HOME/preview/codeledge/snapshot

if [ "$#" -gt 1 ]; then
  echo "usage: $0 [output-dir]" >&2
  exit 1
fi

STAGING_SSH_HOST="coreserver"
STAGING_PATH="domains/stg.codeledge.co/public_html"

FINAL_DIR="${1:-$HOME/preview/codeledge/snapshot}"
FINAL_DIR="${FINAL_DIR%/}"
PARENT_DIR="$(dirname "$FINAL_DIR")"
mkdir -p "$PARENT_DIR"

# 出力先への差し替えを同じファイルシステム上の mv で行うため、作業ディレクトリを出力先の親に作る。
WORK_DIR="$(mktemp -d "$PARENT_DIR/.fetch-snapshot.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "==> ステージングから public_html を取得する (wp-content/themes と wp-content/ai1wm-backups は除く)"
rsync -az \
  --exclude 'wp-content/themes/' \
  --exclude 'wp-content/ai1wm-backups/' \
  -e ssh \
  "${STAGING_SSH_HOST}:${STAGING_PATH}/" \
  "$WORK_DIR/public_html/"

echo "==> ステージングのテーブル接頭辞を読み取る"
# shellcheck disable=SC2029
TABLE_PREFIX="$(ssh "$STAGING_SSH_HOST" "grep '^\$table_prefix' ${STAGING_PATH}/wp-config.php" \
  | sed -E "s/.*=[[:space:]]*'([^']*)'.*/\1/")"
echo "    table_prefix = ${TABLE_PREFIX}"

echo "==> ステージングの DB をダンプして取得する"
# ログインシェルで実行する。コアサーバーの管理画面で選んだ PHP は .bash_profile の PATH にしか入らないため。
# shellcheck disable=SC2029
ssh "$STAGING_SSH_HOST" "bash -lc 'cd ${STAGING_PATH} && wp db export -'" > "$WORK_DIR/db.sql"

echo "==> meta を書き出す"
{
  echo "FETCHED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "TABLE_PREFIX=${TABLE_PREFIX}"
} > "$WORK_DIR/meta"

echo "==> 出力先へ差し替える: ${FINAL_DIR}"
OLD_DIR="${FINAL_DIR}.old"
rm -rf "$OLD_DIR"
if [ -e "$FINAL_DIR" ]; then
  mv "$FINAL_DIR" "$OLD_DIR"
fi
if ! mv "$WORK_DIR" "$FINAL_DIR"; then
  if [ -e "$OLD_DIR" ]; then
    mv "$OLD_DIR" "$FINAL_DIR"
  fi
  exit 1
fi
rm -rf "$OLD_DIR"

echo "==> 完了"
