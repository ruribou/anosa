# Xcode / XcodeGen / シミュレータ のトラブルシュート

前提: Xcode 26 以降・iOS 26 / watchOS 26 SDK。`.xcodeproj` は生成物で git 管理しない（`.gitignore` 済み）。

## xcodebuild が「project が見つからない」/ 古いターゲット構成でビルドされる

**症状**: `xcodebuild: error: 'Anosa.xcodeproj' does not exist.`、または project.yml の変更（ターゲット追加・設定変更）が反映されない

**原因**: `.xcodeproj` は `xcodegen generate` の生成物。clone 直後・rebase 後・project.yml 編集後は再生成が必要

**対処**:

1. リポジトリのルートで `xcodegen generate` を実行してからビルドする
2. verify.conf でも `xcodegen generate` を最初の check に置く（CI も同じ順序）

---

## 複数 worktree の同時ビルドが壊れる・遅い

**症状**: `database is locked`、`Build service could not create build operation`、別 worktree のソースでビルドされたような結果になる

**原因**: 既定の `~/Library/Developer/Xcode/DerivedData` と同じシミュレータを複数の worktree で共有している

**対処**:

1. xcodebuild には必ず `-derivedDataPath ./.derivedData` を付ける（worktree ごとに分かれる。`.gitignore` 済み）
2. `swift test` は `--scratch-path` を指定しない限り各パッケージの `.build/` を使うので worktree 間で衝突しない
3. テストを実行する場合（`test` アクション）は、worktree ごとに別のシミュレータを使う。ビルドだけなら `-sdk iphonesimulator`（watch は `watchsimulator`）で特定の端末を起動せずに済む

---

## シミュレータの destination が見つからない

**症状**: `xcodebuild: error: Unable to find a destination matching the provided destination specifier`

**原因**: 手元と CI（macos-26 ランナー）で入っているランタイム・デバイス名が違う。推測した名前（`iPhone 16` など）を書いた

**対処**:

1. `xcrun simctl list devices available` / `xcrun simctl list runtimes` で実在を確認してから指定する
2. ビルドの check は `-sdk iphonesimulator` / `-sdk watchsimulator` を使い、デバイス名に依存させない（verify.conf の argv は空白を含む引数を書けないので、この形が扱いやすい）
3. 特定デバイスが必要なテストは、名前を固定せずにスクリプトで `xcrun simctl list -j` から選ぶ（verify.conf の argv はシェル展開しないため、スクリプトに切り出す）

---

## 署名エラーでシミュレータ向けビルドが失敗する

**症状**: `Signing for "AnosaShare" requires a development team.`

**原因**: 署名は設定しない方針（CLAUDE.md）。シミュレータ向けでも App Extension / App Group の entitlements があると署名を要求されることがある

**対処**:

1. DEVELOPMENT_TEAM を書いて解決しない（公開リポジトリ。`public-guard` Hook も止める）
2. xcodebuild に `CODE_SIGNING_ALLOWED=NO`（必要なら `CODE_SIGN_IDENTITY=""`）を渡すか、project.yml のシミュレータ向け設定で `CODE_SIGNING_ALLOWED: NO` にする
3. 選んだ方法を docs/DECISIONS.md に 1 行残す

---

## swift test が AnosaKit で失敗する（iOS 専用 API）

**症状**: `swift test` で `no such module 'UIKit'` / `'WidgetKit' is unavailable in macOS` など

**原因**: `swift test` はホストの macOS 向けにビルドする。AnosaKit に UIKit / WatchKit / ActivityKit 依存を入れた

**対処**:

1. AnosaKit の判断エンジン・モデル・文言は Foundation / CoreLocation（座標型）程度に留め、プラットフォーム依存はアプリ側ターゲットに置く
2. どうしても必要な場合は、`swift test` ではなく xcodebuild の `test` アクション（iOS Simulator）で AnosaKitTests を回す方針に切り替え、DECISIONS.md に残す

---

## CI だけ Xcode のバージョンが違う

**症状**: 手元では通るが CI で `'glassEffect' is unavailable` などの API 不在エラー

**原因**: macos-26 ランナーに複数の Xcode があり、既定が想定より古い

**対処**:

1. ci.yml の「最新の Xcode 26 を選択」ステップの `xcodebuild -version` 出力を確認する
2. 手元は `xcodebuild -version` と `xcrun --show-sdk-version --sdk iphonesimulator` で SDK を確認する。`#available` 分岐で回避しない（SPEC: 最低 OS 26 固定）
