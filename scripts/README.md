# 本番からステージングへの反映 (codeledge.co)

`sync-prod-to-stg-codeledge.sh` は、本番 codeledge.co の DB と uploads をステージング stg.codeledge.co へ反映する。
wp-theme-digknow の `scripts/sync-prod-to-stg.sh` と同じ処理で、対象のドメインだけが違う。

コアサーバー上で実行する。本番への書き込みは行わない。themes と plugins は反映しない。

## 何をするか

- 本番とステージングのテーブル接頭辞が一致することを確かめる
- ステージングの DB を `~/work/codeledge-stg-db-backup/` へ退避してから、本番の DB を取り込む
- `wp search-replace` で `https://codeledge.co` を `https://stg.codeledge.co` へ置き換える
- 本番の `wp-content/uploads/` をステージングへ同期する (`--delete` 付き)
- 外部へ出る経路を止める (Google Site Kit / WP Mail SMTP。入っているものだけ)
- 退避した DB を 7 世代残して古いものを消す

## 置き場所と crontab

`develop` への merge で `~/bin-codeledge/` へ転送される。`~/bin` ではない
(wp-theme-digknow の deploy が `~/bin` を `--delete` で上書きするため)。

```
15 5 * * * $HOME/bin-codeledge/sync-prod-to-stg-codeledge.sh >> $HOME/work/sync-prod-to-stg-codeledge.log 2>&1
```

## 退避したダンプから戻す

```
wp --path=$HOME/domains/stg.codeledge.co/public_html db import ~/work/codeledge-stg-db-backup/stg-db-YYYYMMDD.sql
```
