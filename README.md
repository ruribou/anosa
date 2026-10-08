# Anosa（あのさ）

「保存したら、忘れていい。」

行きたい場所を保存しておくと、近くに行ったときなどに、iPhone / Apple Watch の通知・ウィジェット・コンプリケーションで自然に思い出させてくれるアプリ。

## ステータス
M1〜M6 で MVP の機能（保存・判断エンジン・位置情報と通知・ウィジェット・Watch・設定とオンボーディング）がそろった。実機での確認と、署名・ID・アイコンなどの手動作業（下の「手動でやること」）が残っている。仕様は docs/SPEC.md、判断の記録は docs/DECISIONS.md。

## 開発の進め方
- 仕様の正: docs/SPEC.md
- 開発ルール: CLAUDE.md
- 作業はマイルストーン単位のIssueごとに、専用ブランチ（git worktree）で行い、PR経由でmainにマージする。


## 検証
CI（.github/workflows/ci.yml）と同じコマンドで、プロジェクト生成・AnosaKit のテスト・全スキームのシミュレータ向けビルドを行う。中身は .claude/verify.conf。
```sh
.claude/scripts/verify run
```

## 動作確認フロー（シミュレータ）
保存 → 位置の模擬 → 通知 → アクション → ウィジェット更新を一続きで確かめる手順。`<device>` はシミュレータの UDID か名前（`xcrun simctl list devices available` で確認）。他の worktree と同じシミュレータを同時に使わない。

1. ビルドしてインストールする（derivedData は worktree ごとに分ける）。
   ```sh
   xcodegen generate
   xcodebuild -project Anosa.xcodeproj -scheme Anosa \
     -destination 'platform=iOS Simulator,id=<device>' \
     -derivedDataPath ./.derivedData build
   xcrun simctl boot <device>
   xcrun simctl install <device> .derivedData/Build/Products/Debug-iphonesimulator/Anosa.app
   ```
   `-destination` に名前を使うときは `name=<device>`。
2. 初回起動。位置情報を「常に許可」にしてから起動する（DEBUG の起動引数で「行きたい」場所を 1 件追加できる。保存の確認を別の経路でするなら付けなくてよい）。
   ```sh
   xcrun simctl privacy <device> grant location-always com.example.anosa
   xcrun simctl launch <device> com.example.anosa -AnosaDebugAddPlace "東京タワー,35.658581,139.745433"
   ```
   - 初回だけ 3 画面のオンボーディングが出る。「つぎへ」→「はじめる」か「スキップ」で閉じる。もう一度出すときは DEBUG ビルドで `-AnosaResetOnboarding YES` を付けて起動する（`-AnosaDebugAddPlace` と一緒に付けてもよい）。
   - `privacy grant` をしなかった場合は、オンボーディングを閉じた後に「使用中のみ」のダイアログが出て、許可すると「常に許可」の説明が続く。
   - 通知の許可は simctl では付与できない。位置情報が許可された後に出るダイアログで「許可」をタップする。
3. 保存。次のどれかで「行きたい」場所を入れる（手順 2 の起動引数で入れた場合は省いてよい）。
   - アプリ内: 右上の「場所を追加」（＋）で場所名を検索して選ぶ。
   - Share Extension: Safari などで地図の URL（例 `https://maps.apple.com/?q=東京タワー&ll=35.658581,139.745433`）を開き、共有シートから「Anosa」を選ぶ。「保存したよ。あとは忘れていいよ」が出たら閉じてよい（候補が複数なら選ぶ画面が出る）。共有シートに出ないときは「その他」から追加する。
   - DEBUG: `-AnosaDebugAddPlace "<名前>,<緯度>,<経度>"` を付けて起動する（同じ名前・座標なら追加しない）。

   Share Extension で保存した場所は App Group 経由でアプリと共有する。署名なしのビルドで App Group が使えないとアプリ側の一覧に出ないことがある。起動中のアプリにすぐ反映されるかも未確認のため、出ないときはアプリを終了して開き直すか、アプリ内の追加・起動引数で確かめる。
4. 位置の模擬。先に離れた地点に置いてから、場所の近く（既定 500m 以内）へ動かす。
   ```sh
   xcrun simctl location <device> set 35.681236,139.767125
   xcrun simctl location <device> start --speed=50 35.681236,139.767125 35.6700,139.7550 35.6590,139.7450
   ```
   `start` の代わりに `set 35.6590,139.7450` してからアプリを前面に出してもよい（前面に来たときに現在地を取り直す）。
   シミュレータではリージョン監視（CLMonitor）が使えないため、significant-location-change（`start` での移動）か前面復帰の経路で確認する。`set` の 1 回だけでは位置更新が届かないことがある。
5. 通知。近くに来ると「近くにあるよ」などの見出しと「<場所名>・徒歩<n>分」の通知が出る（アプリを開いているときもバナーで出る）。
6. アクション。通知を長押し（または通知センターで引き下げ）すると「行ってみる」「今日はやめる」「もう行った」が出る。
   - 「行ってみる」: マップで徒歩ルートを開く。場所の状態は変えない。
   - 「今日はやめる」: 静かにする時間が明けるまで（既定 次の 8:00、静かにする時間をオフにしていれば翌日 0 時まで）その場所を通知しない。
   - 「もう行った」: 場所を「行った」に移す。アプリの一覧の「行った」に出る。
7. ウィジェット更新。ホーム画面を長押しして Anosa の small ウィジェット（「いちばん近い行きたい場所」）を置くと、「いちばん近く」に場所名と距離・徒歩分が出る。手順 4 の `set` / `start` で位置を動かすと、位置更新のたびに内容が変わる（ウィジェットはアプリが位置更新で保存した内容を出し、自分では更新を求めない）。
   - 「もう行った」などの状態変更は、その場ではウィジェットに反映されず、次の位置更新（アプリを前面に出したときの取り直しを含む）で反映される（M4 の決定）。
   - 位置が取れていないときは「現在地がわかったら教えるね」、近くに場所がないときは「近くにはまだないみたい」と出る。

ログは次で見る（座標は出さない）。
```sh
xcrun simctl spawn <device> log stream --predicate 'subsystem == "com.example.anosa"' --level info
```

通知が出ないときは次を確認する。数値は既定値で、アプリの「設定」（左上の歯車）で変えている場合はその値で判断される。
- 静かにする時間（既定 22:00〜8:00）ではないか
- 1 日の通知の上限（既定 2 回、設定で 1〜3 回）に当たっていないか、同じ場所の 7 日のクールダウン中ではないか
- 通知する距離（既定 500m、設定で 300m・500m・1.0km）の内側にいるか
- 「今日はやめる」でスヌーズ中、または「行った」「アーカイブ」になっていないか
- 通知が許可されているか（許可がないときは判断も記録もしない）

設定の変更は再起動なしで次の判断から効く。通知する距離を変えると現在地を取り直す。

やり直すときは `xcrun simctl uninstall <device> com.example.anosa` してからインストールし直す（全部消すなら `xcrun simctl shutdown <device>` → `xcrun simctl erase <device>`）。

## シミュレータでの動作確認（Watch 同期）
以下の手順は、watchOS シミュレータのランタイムがない環境で書いたため確かめていない（ビルドが通ることだけ確認済み）。`<phone>` / `<watch>` はシミュレータの UDID か名前。

1. watchOS のランタイムを入れ（Xcode の Settings > Components）、iOS と watchOS のシミュレータをペアにして起動する。
   ```sh
   xcrun simctl list pairs
   xcrun simctl pair <watch> <phone>   # ペアがなければ作る
   xcrun simctl boot <phone>
   xcrun simctl boot <watch>
   ```
2. iPhone 側は「動作確認フロー」の手順 1〜4 でインストール・場所の追加・位置の移動をする。Watch アプリは別にビルドして Watch のシミュレータに入れる。
   ```sh
   xcodebuild -project Anosa.xcodeproj -scheme AnosaWatch \
     -destination 'platform=watchOS Simulator,id=<watch>' \
     -derivedDataPath ./.derivedData build
   xcrun simctl install <watch> .derivedData/Build/Products/Debug-watchsimulator/AnosaWatch.app
   xcrun simctl launch <watch> com.example.anosa.watchkitapp
   ```
3. iPhone で位置が更新されると、Watch アプリの一覧に近い順 3 件が出る。「もう行った」を押すとすぐ一覧から消え、iPhone の一覧では「行った」に移る。コンプリケーションは文字盤の編集で「近くの行きたい場所」を追加して確かめる。

ログは `xcrun simctl spawn <phone|watch> log stream --predicate 'subsystem == "com.example.anosa" AND category == "watch"' --level info` で見る。
署名なしのシミュレータビルドでは App Group が使えず、Watch アプリとコンプリケーションでデータが共有されないことがある（コンプリケーションが「現在地がわかったら教えるね」〔inline は「現在地を待ってるよ」〕のままになる）。

## 手動でやること
リポジトリでは設定・確認しない（できない）ため、人が行う作業。ID は公開リポジトリにコミットしない。

- **署名（Team / Provisioning）**: リポジトリでは設定しない（project.yml に DEVELOPMENT_TEAM を書かない）。実機で動かすときは手元の Xcode で各ターゲット（Anosa・AnosaShare・AnosaWidget・AnosaWatch・AnosaWatchWidget）に Team を設定する。
- **Bundle ID**: `com.example.anosa` 系のプレースホルダー。project.yml の `options.bundleIdPrefix` と各ターゲットの `PRODUCT_BUNDLE_IDENTIFIER`（`com.example.anosa`・`.share`・`.widget`・`.watchkitapp`・`.watchkitapp.widget`）、AnosaWatch の `WKCompanionAppBundleIdentifier` を実際の ID に置き換える。ログの subsystem（各ソースの `Logger(subsystem: "com.example.anosa", ...)`）も合わせて変えるとよい。
- **App Group ID**: プレースホルダー `group.com.example.anosa` を、Developer で作った実際の App Group に置き換える。置き換える箇所:
  - project.yml の 5 ターゲットの `entitlements.properties` の `com.apple.security.application-groups`
  - 生成される entitlements（Anosa/Anosa.entitlements・AnosaShare/AnosaShare.entitlements・AnosaWidget/AnosaWidget.entitlements・AnosaWatch/AnosaWatch.entitlements・AnosaWatchWidget/AnosaWatchWidget.entitlements。`xcodegen generate` で project.yml から作り直される）
  - AnosaKit/Sources/AnosaKit/Persistence/AnosaStore.swift の `AnosaStore.appGroupIdentifier`（SwiftData のストアと共有 UserDefaults が使う）
- **実機でのバックグラウンド位置情報テスト**: アプリを閉じた状態で近くに行ったときの通知、リージョン監視（CLMonitor）による侵入の検知、significant-location-change での再起動は、シミュレータでは確かめられない。実機で「常に許可」にして、実際に移動して確かめる。
- **Apple Watch 実機確認**: iPhone → Watch の同期（近い順の一覧）、Watch からの「もう行った」の反映、コンプリケーション（inline / circular / rectangular / corner）と Smart Stack、iPhone の通知の Watch へのミラーとアクション。Watch のシミュレータ手順も未確認のため、実機で確かめる。
- **アイコンの最終デザイン**: いまはプレースホルダーのアイコン `Shared/AppIcon.icon`（Icon Composer の形式。背景はコーラル寄りのオレンジの塗り、前景は白い吹き出し兼ピンの SVG 1 枚）が入っていて、iOS アプリ（Anosa）と Watch アプリ（AnosaWatch）の両方がこれを使う。差し替えの手順:
  1. `Shared/AppIcon.icon` を Icon Composer（Xcode に同梱。Xcode のメニュー Open Developer Tool から開ける）で開く。
  2. 前景のレイヤー `Foreground`（`Shared/AppIcon.icon/Assets/Foreground.svg`）を新しいデザインの SVG に置き換え、背景の塗り（Fill）の色を変える。レイヤー構成は背景＋前景 1 枚のままにする（SPEC）。Watch の丸い形（circles）でも切れないよう、前景は中央に寄せる。
  3. 保存すると `Shared/AppIcon.icon/icon.json` と `Assets/` が更新される。ファイル名 `AppIcon.icon` のままなら project.yml の変更は不要。名前や場所を変えるときは、project.yml の Anosa と AnosaWatch の `sources` にある `Shared/AppIcon.icon` と、両ターゲットの `settings.base.ASSETCATALOG_COMPILER_APPICON_NAME`（`.icon` のファイル名から拡張子を除いたもの）を合わせて変え、`xcodegen generate` する。
  4. 各表示での見え方を書き出して確かめる（`--rendition` は Default / Dark / TintedLight / TintedDark / ClearLight / ClearDark、Watch は `--platform watchOS`）:
     ```sh
     "/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" \
       Shared/AppIcon.icon --export-image --output-file /tmp/AppIcon-Default.png \
       --platform iOS --rendition Default --width 1024 --height 1024 --scale 1
     ```
  5. シミュレータでホーム画面に表示されることを確かめる（書き出した PNG はリポジトリに入れない）。
