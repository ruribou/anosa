# public-guard — 公開リポジトリ向けの commit / push 前チェック

`scripts/public-guard`（配置後は `.claude/scripts/public-guard`）は PreToolUse の Hook。Anosa は公開リポジトリなので、`git commit` / `git push` の直前に差分を調べ、載せてはいけない可能性がある情報が見つかったときだけ `ask` を返す（CLAUDE.md「Public リポジトリとしての注意」の機械的な補助）。

- 権限を広げない（`allow` を返さない）。`deny` もしない。誤検出がありうるため、止めて利用者に判断を委ねる
- 見るのは追加行とファイル名だけ。差分の内容はどこにも保存・送信しない

## 対象の差分

| 操作 | 調べる範囲 |
| --- | --- |
| `git commit` | `git diff --cached` と `git diff`（`-a` や pathspec 付きを拾うため両方。過検出は許容） |
| `git push` | `@{upstream}..HEAD`。upstream が無ければ `origin/main..HEAD`。どちらも無ければ見ない |

## 検出するもの

| 種類 | 例 |
| --- | --- |
| 署名・鍵・位置ログのファイル | `*.mobileprovision` `*.provisionprofile` `*.p12` `*.p8` `*.cer` `*.pem` `*.key` `AuthKey_*` `*.gpx` |
| Team ID の実値 | `DEVELOPMENT_TEAM` に英大文字・数字 10 桁の値、plist の `TeamIdentifier` |
| プロファイル | `PROVISIONING_PROFILE` / `PROVISIONING_PROFILE_SPECIFIER` に値がある |
| 個人名入りの署名 ID | `Apple Development` / `iPhone Developer` などの後にコロンと氏名が続く文字列 |
| 実機 UDID | 16 進 8 桁・ハイフン・16 進 16 桁の形式（2018 年以降の端末） |
| 秘密鍵 | PEM の PRIVATE KEY ヘッダー |

## 限界

- 位置情報の実データ（自宅・職場の座標など）は、テスト用の座標と区別できないため検出しない。テストやサンプルでは公共のランドマーク（例: 東京駅）の座標を使う（`skills/project-knowledge/references/review-anosa.md`）
- 旧形式（40 桁の 16 進）の UDID は git の SHA と区別できないため検出しない
- `gh pr create` の本文、Issue・コメントへの投稿は対象外

## 確認方法

```bash
jq -n --arg c 'git commit -m x' --arg d "$PWD" '{tool_input:{command:$c},cwd:$d}' | .claude/scripts/public-guard
```

出力が空なら通過。
