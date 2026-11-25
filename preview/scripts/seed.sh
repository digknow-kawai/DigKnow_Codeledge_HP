#!/usr/bin/env bash
set -euo pipefail

# スナップショット (fetch-snapshot.sh が作ったもの) の中身を、起動済みの preview スタック (web / db) へ流し込む。
# docker compose up -d 済みであることが前提。ステージングと本番への書き込みは行わない。
#
# 使い方: seed.sh <PR番号> <プレビューのホスト名> <ビルド済みテーマのパス>

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <pr-number> <preview-host> <theme-path>" >&2
  exit 1
fi

PR_NUMBER="$1"
PREVIEW_HOST="$2"
THEME_PATH="$3"

if [ ! -d "$THEME_PATH" ]; then
  echo "テーマのパスが見つからない: $THEME_PATH" >&2
  exit 1
fi
export PR_NUMBER

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREVIEW_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PREVIEW_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo ".env が見つからない (preview/.env.example を元に用意する): $ENV_FILE" >&2
  exit 1
fi
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${DB_HOST:?DB_HOST が .env に無い}"
: "${DB_NAME:?DB_NAME が .env に無い}"
: "${DB_USER:?DB_USER が .env に無い}"
: "${DB_PASSWORD:?DB_PASSWORD が .env に無い}"
: "${DB_ROOT_PASSWORD:?DB_ROOT_PASSWORD が .env に無い}"

STAGING_URL="https://stg.codeledge.co"
THEME_NAME="codeledge.co_v1.7"
DOC_ROOT="/var/www/vhosts/localhost/html"

COMPOSE=(docker compose --project-name "preview-codeledge-pr-${PR_NUMBER}" -f "$PREVIEW_DIR/compose.yml")

SNAPSHOT_DIR="${PREVIEW_SNAPSHOT_DIR:-$HOME/preview/codeledge/snapshot}"
SNAPSHOT_META="$SNAPSHOT_DIR/meta"

if [ ! -d "$SNAPSHOT_DIR" ] || [ ! -r "$SNAPSHOT_META" ]; then
  echo "スナップショットが見つからない (先に fetch-snapshot.sh を実行する): $SNAPSHOT_DIR" >&2
  exit 1
fi

# スナップショットの差し替えは、public_html の展開と db.sql の流し込みの間にも起こりうる。
# 途中で入れ替わると新旧が混ざった状態を読むため、読み出しの間ずっと共有ロックを保つ。
# 差し替える側は同じファイルで排他ロックを取る
exec 9>>"$(dirname "$SNAPSHOT_DIR")/.snapshot.lock"
flock -s 9

set -a
# shellcheck disable=SC1090
source "$SNAPSHOT_META"
set +a

: "${TABLE_PREFIX:?TABLE_PREFIX がスナップショットの meta に無い}"

echo "==> スナップショットを使う: ${SNAPSHOT_DIR} (取得 ${FETCHED_AT:-不明})"

echo "==> db の起動を待つ"
until "${COMPOSE[@]}" exec -T db mysqladmin ping -uroot -p"${DB_ROOT_PASSWORD}" --silent; do
  sleep 1
done

echo "==> public_html を web のボリュームへ展開する"
"${COMPOSE[@]}" cp "$SNAPSHOT_DIR/public_html/." "web:${DOC_ROOT}/"

echo "==> wp-config.php を生成する"
"${COMPOSE[@]}" exec -T web wp config create \
  --allow-root \
  --path="${DOC_ROOT}" \
  --dbhost="${DB_HOST}" \
  --dbname="${DB_NAME}" \
  --dbuser="${DB_USER}" \
  --dbpass="${DB_PASSWORD}" \
  --dbprefix="${TABLE_PREFIX}" \
  --force

echo "==> ダンプを db サービスへ流し込む"
"${COMPOSE[@]}" exec -T db mysql \
  -uroot \
  -p"${DB_ROOT_PASSWORD}" \
  "${DB_NAME}" < "$SNAPSHOT_DIR/db.sql"

echo "==> .htaccess から認証の4行を落とす"
"${COMPOSE[@]}" exec -T web sed -i -E \
  '/^AuthType /d;/^AuthName /d;/^AuthUserFile /d;/^Require /d' \
  "${DOC_ROOT}/.htaccess"

echo "==> URL をプレビューのホスト名へ置換する"
"${COMPOSE[@]}" exec -T web wp search-replace \
  --allow-root \
  --path="${DOC_ROOT}" \
  "${STAGING_URL}" \
  "https://${PREVIEW_HOST}"

echo "==> 外部送信を伴うプラグインを無効化する"
# codeledge.co に入っているものだけを止める。入っていないものを渡すと wp plugin deactivate が失敗するため、
# 先に有無を確かめる
WP=("${COMPOSE[@]}" exec -T web wp --allow-root --path="${DOC_ROOT}")
for PLUGIN in google-site-kit wp-mail-smtp; do
  if "${WP[@]}" plugin is-installed "$PLUGIN"; then
    "${WP[@]}" plugin deactivate "$PLUGIN"
  fi
done

echo "==> SEO SIMPLE PACK が入っていれば、解析の設定を空にする"
# Site Kit を止めても、このプラグインは GA4 の測定 ID を独立して持ち、gtag のタグを出力する
if "${WP[@]}" plugin is-installed seo-simple-pack; then
  for KEY in google_g_id google_ua_id webmaster_google; do
    "${WP[@]}" option patch update ssp_settings "$KEY" '' || true
  done
fi

echo "==> ビルド済みテーマを配置する"
"${COMPOSE[@]}" exec -T web mkdir -p "${DOC_ROOT}/wp-content/themes/${THEME_NAME}"
"${COMPOSE[@]}" cp "${THEME_PATH}/." "web:${DOC_ROOT}/wp-content/themes/${THEME_NAME}/"

echo "==> web を再起動して .htaccess を読み直させる"
# OpenLiteSpeed は起動後に置かれた .htaccess を自動では読み込まない。
# 再起動しないと WordPress の rewrite が効かず、トップ以外がすべて 404 になる。
"${COMPOSE[@]}" restart web
until "${COMPOSE[@]}" exec -T web curl -sS -o /dev/null http://127.0.0.1/ 2>/dev/null; do
  sleep 1
done

echo "==> 完了"
