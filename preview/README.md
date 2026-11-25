# PR プレビュー環境 (codeledge.co)

wp-theme-digknow の `preview/` と同じ仕組みを、codeledge.co 向けに名前と場所だけ変えたもの。
仕組みの詳細 (認証・OpenLiteSpeed の癖・本番との差) は wp-theme-digknow の `preview/README.md` と
`docs/preview-environment.md` を参照する。

## digknow 版との違い

| 項目 | digknow.co.jp | codeledge.co (これ) |
|---|---|---|
| ホスト名 | `pr-<番号>.preview.digknow.co.jp` | `codeledge-pr-<番号>.preview.digknow.co.jp` |
| Compose のプロジェクト名 | `preview-pr-<番号>` | `preview-codeledge-pr-<番号>` |
| インスタンス上の置き場所 | `~/preview/` | `~/preview/codeledge/` |
| スナップショットの取得元 | `stg.digknow.co.jp` | `stg.codeledge.co` |
| テーマ名 | `digknow_v2.1.1` | `codeledge.co_v1.7` |

Traefik と外部ネットワーク `preview-proxy` は digknow 側と共用で、このリポジトリには置かない。

## インスタンス上の配置

```
~/preview/codeledge/snapshot/       ステージングのスナップショット。preview-snapshot が作る
~/preview/codeledge/pr-<番号>/      PR ごとのスタック。preview-up が転送する
~/preview/codeledge/.snapshot.lock  スナップショットの読み書きの排他に使う
```

## ローカルで 1 組だけ試す

手順は wp-theme-digknow の `preview/README.md` の 1〜8 と同じ。読み替えるのは次の 3 点だけ。

- スナップショットの既定の置き場所は `~/preview/codeledge/snapshot`
- `seed.sh` に渡すホスト名は `codeledge-pr-<番号>.preview.digknow.co.jp` の形にする
- `docker compose exec` / `logs` を叩くときのプロジェクト名は `preview-codeledge-pr-${PR_NUMBER}`
