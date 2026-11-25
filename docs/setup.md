# 立ち上げ手順 (1 度だけ行う手作業)

上から順に行う。リポジトリのコード側 (ワークフロー・Compose・スクリプト) は揃っており、
ここに書いたのは GitHub の設定とサーバー上の作業だけである。

## 1. GitHub のブランチと保護

1. `main` と `develop` を作る (どちらも同じ初期コミットから)
2. Settings → General で既定ブランチを `develop` にする。
   `main` への PR を merge したときに head の `develop` が自動削除されるのを防ぐため (wp-theme-digknow と同じ理由)
3. Settings → General → Pull Requests で「Automatically delete head branches」を有効にする
4. Settings → Rules で `main` と `develop` に ruleset を掛ける (PR 必須・直接 push とブランチ削除の禁止)

このリポジトリは個人アカウント (`digknow-kawai`) の配下にあるため、organization secret も
チーム `ruleset-bypass` も使えない。DigKnow organization へ移すと wp-theme-digknow と同じ運用に揃えられる。

## 2. Environments

Settings → Environments で 2 つ作る。

| 名前 | 設定 |
|---|---|
| `production` | Deployment branches を `main` のみに絞る |
| `staging` | 制限なし |

## 3. Repository secrets

Settings → Secrets and variables → Actions に登録する。値は wp-theme-digknow で使っているものと同じでよい。

| 名前 | 中身 | 使うワークフロー |
|---|---|---|
| `CORESERVER_SSH_KEY` | コアサーバーのデプロイ専用鍵 (パスフレーズなし) | Deploy theme / Import theme / Preview snapshot |
| `PREVIEW_SSH_KEY` | プレビューのインスタンス `ubuntu@13.192.94.80` に入る鍵 | Preview up / down / snapshot |
| `PREVIEW_HTPASSWD` | プレビューのベーシック認証の htpasswd (bcrypt のハッシュのまま) | Preview up |

wp-theme-digknow の `PREVIEW_HTPASSWD` は organization secret で、公開範囲がそのリポジトリに絞られている。
同じ値を repository secret としてこちらにも登録するか、organization secret の公開範囲にこのリポジトリを加える
(organization へ移した場合のみ可能)。

## 4. 本番のテーマを取り込む

Actions → `Import theme` → Run workflow。
本番の `codeledge.co_v1.7` を取得し、ブランチ `import/theme-from-production` へ push する。
そこから `develop` への PR を作り、中身を確かめて merge する。

取り込むまでは `theme/` が空で、`Deploy theme` と `Preview up` はテーマの検証で止まる (サーバーのテーマは消えない)。

## 5. ステージング stg.codeledge.co を作る

digknow.co.jp の stg と同じ作り方をする。コアサーバーの管理画面で行う。

1. DirectAdmin でサブドメイン `stg.codeledge.co` を追加する
2. Installatron のクローン機能で `codeledge.co` を `stg.codeledge.co` へ複製する。
   **Installatron の Sync は使わない** (ステージング → 本番の向きで走ると本番の DB が失われる)
3. Let's Encrypt の証明書に `stg.codeledge.co` を含める
4. ベーシック認証を掛ける: `public_html/.htaccess` に以下を足し、`.htpasswd` は `public_html` の外に置く

   ```
   AuthType Basic
   AuthName "Staging"
   AuthUserFile /home/sjs86huov6g9j/domains/stg.codeledge.co/.htpasswd
   Require valid-user
   ```

5. 検索エンジンにインデックスさせない (設定 → 表示設定 → 検索エンジンでの表示)

## 6. 本番 → ステージングの日次反映を登録する

`develop` へ 1 度 merge すると、`Deploy theme` が `scripts/` をコアサーバーの `~/bin-codeledge/` へ転送する。
その後、コアサーバーの crontab に次の行を足す (digknow.co.jp の 05:00 とずらす)。

```
15 5 * * * $HOME/bin-codeledge/sync-prod-to-stg-codeledge.sh >> $HOME/work/sync-prod-to-stg-codeledge.log 2>&1
```

`~/bin` には置かない。wp-theme-digknow の deploy が `~/bin` を `--delete` 付きで上書きするため消される。

初回は手で 1 度走らせて、ステージングが本番と同じ内容になることを確かめる。

## 7. 最初のスナップショットを作る

Actions → `Preview snapshot` → Run workflow。
プレビューのインスタンスに `~/preview/codeledge/snapshot/` ができる。以後は毎朝 06:20 (JST) に自動で更新される。

## 8. 動作確認

適当な変更で作業ブランチから `develop` への PR を作り、次を確かめる。

- `Preview up` が成功し、PR に `https://codeledge-pr-<番号>.preview.digknow.co.jp/` がコメントされる
- URL を開くとベーシック認証が出て、通すと変更が載った codeledge.co が表示される
- トップ以外のページ (例: `/price/`、`/blog/`) も 404 にならない
- PR を close するとプレビューが消える

プレビューのホスト名は既存の `*.preview.digknow.co.jp` の A レコードと Traefik をそのまま使うため、
DNS とプロキシの追加作業は要らない。証明書は初回アクセスの直前に Traefik が自動で取る。
