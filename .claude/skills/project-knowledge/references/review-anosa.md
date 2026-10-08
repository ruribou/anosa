# レビュー事例・観点（Anosa 固有）

一般的な観点は `.claude/review-patterns.md`。ここには Anosa 固有のものだけを書く。仕様の正は `docs/SPEC.md`。

## 思想: 「保存したら、忘れていい。」に反する UI・振る舞い

**対象**: `Anosa/` の画面、`AnosaShare/`、`AnosaWatch/`

**指摘内容**: 管理画面を凝る（並べ替え・タグ・フィルタ・地図での一覧管理）、保存後に追加入力を求める、Watch アプリで操作を増やす

**望ましい形**: 保存後は「保存したよ。あとは忘れていいよ」程度の一言ですぐ閉じる。Watch は近い順 3 件＋「行ってみる」「もう行った」だけ。主役は通知・ウィジェット・コンプリケーション

---

## 判断エンジンの純粋性と設定の一元化

**対象**: `AnosaKit` の判断エンジン・設定構造体

**指摘内容**: エンジン内で `Date()` / `CLLocationManager` / `UserDefaults` / 乱数を直接呼ぶ。距離 500m・1 日 2 回・クールダウン 7 日・静音 22〜8 時などの数値が設定構造体の外に散る

**望ましい形**: 現在地・現在時刻・場所一覧・通知履歴・設定を引数で受け取り、結果だけを返す。パラメータは 1 つの設定構造体に集約。テストは各ルールの境界値（ちょうど 500m、22:00 / 7:59、クールダウン満了の瞬間、上限ちょうど）と条件の両側を持つ

---

## タイムゾーン・暦に依存したテスト

**対象**: 静音時間帯・1 日上限・スヌーズ・クールダウンのテスト

**指摘内容**: `Calendar.current` / `TimeZone.current` に依存し、CI（UTC）と手元（JST）で結果が変わる

**望ましい形**: Calendar / TimeZone を設定または引数で注入し、テストでは固定する

---

## 位置情報・プライバシー

**対象**: 位置情報、App Group、WatchConnectivity、ログ

**指摘内容**: 座標や場所名を `print` / `os_log`（public）で出す、外部送信につながるコード（URLSession での送信、アナリティクス SDK）を足す

**望ましい形**: 位置情報は端末外に出さない。ログに出す場合は `privacy: .private`。Watch への送信は applicationContext の最小限のスナップショットのみ。テスト・サンプル・README の座標は公共のランドマーク（例: 東京駅 35.6812, 139.7671）を使い、実際の自宅・職場などの座標を使わない

---

## 公開リポジトリに載せない値

**対象**: `project.yml`、`*.entitlements`、`Info.plist`、README、ログ・PR 本文

**指摘内容**: DEVELOPMENT_TEAM、プロビジョニングプロファイル、実機 UDID、実在の App Group ID を書く

**望ましい形**: Bundle ID は `com.example.anosa` 系、App Group は `group.com.example.anosa` 系のプレースホルダー。差し替えは README の「手動でやる必要があること」に書く

---

## Liquid Glass の使い方

**対象**: SwiftUI のビュー

**指摘内容**: NavigationStack / toolbar / TabView に独自背景（`.toolbarBackground(.visible)`・不透明な色）を重ねる、リストなどのコンテンツ層に `glassEffect` を付ける、ガラスの上にガラスを重ねる、Watch アプリに独自装飾を足す

**望ましい形**: 標準コンポーネントのままにする。`glassEffect` / `GlassEffectContainer` はコンテンツの上に浮く操作系（保存後の確認チップ、地図上の浮遊ボタン）だけ。ボタンは `.glass` / `.glassProminent` を優先。API 名・引数は推測せずビルドで確認する

---

## OS バージョン分岐

**対象**: Swift 全般

**指摘内容**: `#available(iOS 26, *)` / `@available` による分岐、古い OS 向けの代替実装

**望ましい形**: 最低 OS は iOS 26 / watchOS 26 固定。分岐を入れない

---

## ウィジェット / コンプリケーションの表示モード

**対象**: `AnosaWidget/`、`AnosaWatchWidget/`

**指摘内容**: accented / vibrant モードで色に意味を持たせて破綻する、背景を `.background` で塗る、位置変化時に `WidgetCenter.shared.reloadAllTimelines()` を呼んでいない、relevance を設定していない

**望ましい形**: `containerBackground` を使い、`widgetAccentable` と `widgetRenderingMode` を考慮する。各 family（small / accessory 系、watch の inline / circular / rectangular / corner）を Preview で確認する

---

## 文言

**対象**: UI 文言、通知文言、Info.plist の利用目的文言

**指摘内容**: 英語のまま、押し付けがましい・長い通知文言、文言がコード中に散らばる、title にアプリ名を重ねる（見出しに「Anosa」が自動表示される）

**望ましい形**: すべて日本語。通知 title は「近くにあるよ」「ちょっと寄れそう」「そういえば、ここ」のような短い語りかけ、body は「{場所名}・徒歩{n}分」。通知文言のバリエーションは AnosaKit 内の 1 ファイルに集約する

---

## スコープ外の混入

**対象**: 全体

**指摘内容**: バックエンド・アカウント・クラウド同期・課金・広告・アナリティクス・営業時間の外部 API・AI おすすめを足す。他マイルストーン（M 番号）の担当範囲を先回りして実装する

**望ましい形**: 対象 Issue の範囲だけ。必要な抽象（例: OpeningHoursProvider）はプロトコル＋スタブに留める
