# Claude Code での作業ルール

codeledge.co の見た目を変える依頼は、digknow.co.jp (wp-theme-digknow) と同じ手順で反映する。

1. 指定された作業ブランチ (`claude/...`) で `theme/` 配下を編集する。1 つの変更を 1 コミットにし、
   コミットメッセージは日本語で「何をどう変えたか」を書く
2. 作業ブランチを push し、ユーザーに求められたら `develop` 向けの PR を作る
3. `Preview up` が `https://codeledge-pr-<PR番号>.preview.digknow.co.jp/` を立て、PR に URL をコメントする。
   見た目の確認はそこで行う (ベーシック認証あり)
4. 修正は同じブランチへ追加の push で行う。push のたびにプレビューは作り直される
5. `develop` への merge でステージング `https://stg.codeledge.co/` に、
   `develop` → `main` の merge で本番 `https://codeledge.co/` に反映される

守ること:

- `main` / `develop` へ直接 push しない
- 変更してよいのは原則 `theme/` 配下。`preview/` と `.github/` は環境そのものなので、依頼が無い限り触らない
- コアサーバーの `~/bin` やプレビューのインスタンス上の `~/preview/` 直下は wp-theme-digknow のもの。
  こちらの資源は `~/bin-codeledge` と `~/preview/codeledge/` に閉じる
