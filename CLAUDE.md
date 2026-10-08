# Anosa 開発ルール

- 仕様の正は docs/SPEC.md。作業前に読む。
- Issueに「対象外」の記載がない場合は、SPEC.md の「スコープ外」と、他のマイルストーン（M番号）の担当範囲を対象外とみなす。
- 実装フロー（検証・レビュー・PR作成）は .claude/ の /implement-issue に従う。CIの監視は /watch-pr。
- 不明点は質問で止まらず、合理的に仮定して docs/DECISIONS.md に1行ずつ追記する。権限や要件が足りず決められない場合は、BLOCKED として止まる。
- 検証コマンドは .claude/verify.conf に明示し、CI（.github/workflows/ci.yml）と同じコマンドにする。

## 並列開発（複数のworktree）
- xcodebuild では -derivedDataPath をworktreeごとに分ける（例: ./.derivedData）。
- シミュレータもworktree間で分け、同時ビルドの衝突を避ける。
- project.yml は競合しやすい。mainに先にマージされた変更がある場合は、作業ブランチをmainにrebaseしてから続ける。

## Public リポジトリとしての注意
- このリポジトリは公開されている。Team ID、実機UDID、秘密情報、位置情報の実データ、個人情報を、コミット・Issue・PR・ログに含めない。
- 認証情報・トークンをコミットしない。

## やらないこと
- 署名（Team / Provisioning）の設定。
- 課金、広告、アカウント、バックエンド、アナリティクスの追加。
