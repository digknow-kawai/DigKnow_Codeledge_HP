# DigKnow_Codeledge_HP

codeledge.co (Codeledge プロダクトサイト) の WordPress テーマ `codeledge.co_v1.7`。

開発の流れと環境の組み立ては [wp-theme-digknow](https://github.com/DigKnow/wp-theme-digknow) (digknow.co.jp) と同じにしてある。

## 画面の変更が反映されるまで

```
作業ブランチ (claude/... など)
  │  develop への PR を作る
  ▼
PR プレビュー  https://codeledge-pr-<PR番号>.preview.digknow.co.jp/   ← PR への push ごとに作り直す
  │  確認して develop へ merge
  ▼
ステージング   https://stg.codeledge.co/
  │  develop → main の PR を merge
  ▼
本番           https://codeledge.co/
```

| 操作 | 動くワークフロー | 結果 |
|---|---|---|
| PR を作る / PR へ push する | `Preview up` | PR 専用の WordPress を作り直し、URL を PR にコメントする |
| PR を close / merge する | `Preview down` | その PR のプレビューを壊す |
| `develop` へ merge | `Deploy theme` | `theme/` をステージングへ転送する |
| `main` へ merge | `Deploy theme` | `theme/` を本番へ転送する |
| 毎朝 06:20 (JST) | `Preview snapshot` | ステージングの DB と uploads をプレビュー用に写す |
| 手動 (初回のみ) | `Import theme` | 本番のテーマを `theme/` へ取り込む |

プレビューの中身は「ステージングの写し (DB / uploads / プラグイン) + PR のブランチのテーマ」。
ベーシック認証は digknow.co.jp のプレビューと同じ資格情報を使う。

## 構成

| パス | 内容 |
|---|---|
| `theme/` | テーマの実体。この配下だけをサーバーへ転送する |
| `preview/` | PR プレビューの Docker Compose 定義とスクリプト |
| `scripts/` | コアサーバーで動かす運用スクリプト (本番 → ステージングの日次反映) |
| `docs/setup.md` | この環境を立ち上げるときに 1 度だけ行う手作業 |

## ビルド

取り込んだ時点のテーマは制作元の納品物 (`dist/` 込み) で、ビルドの構成を持たない。
ワークフローは `package.json` が無ければビルドを飛ばし、`theme/` をそのまま転送する。
SCSS / JS のソースを入手したら、digknow.co.jp と同じく `src/` と `package.json` を足し、
`build` (本番用) と `build:map` (ステージング・プレビュー用) の 2 つのスクリプトを定義する。
その時点で `theme/dist/` を `.gitignore` に入れる。

## デプロイ

転送先は GMO コアサーバー (digknow.co.jp と同じアカウント) の以下のパス。

```
本番          ~/domains/codeledge.co/public_html/wp-content/themes/codeledge.co_v1.7/
ステージング  ~/domains/stg.codeledge.co/public_html/wp-content/themes/codeledge.co_v1.7/
```

`--delete` を付けているため、サーバー側にあって `theme/` に無いファイルは削除される。
`theme/style.css` が無いと転送前に止まるので、`Import theme` を済ませる前に誤って空のテーマを送ることはない。

## 他リポジトリとの共有物 (壊さないこと)

| 共有物 | 注意 |
|---|---|
| コアサーバーの `~/bin` | wp-theme-digknow が `--delete` 付きで転送している。こちらのスクリプトは `~/bin-codeledge` に置く |
| プレビューのインスタンス `13.192.94.80` | こちらのものはすべて `~/preview/codeledge/` の下に置く |
| Traefik / `preview-proxy` ネットワーク | wp-theme-digknow の `Preview proxy` が管理する。こちらからは触らない |
| Docker のプロジェクト名 / Traefik のルーター名 | `preview-codeledge-pr-<番号>` / `codeledge-pr-<番号>` として衝突を避ける |

## 関連

- 初回の立ち上げ手順: `docs/setup.md`
- プレビューの設計 (方式・認証・データの流れ): wp-theme-digknow の `docs/preview-environment.md`
