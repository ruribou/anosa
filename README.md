# Anosa（あのさ）

「保存したら、忘れていい。」

行きたい場所を保存しておくと、近くに行ったときなどに、iPhone / Apple Watch の通知・ウィジェット・コンプリケーションで自然に思い出させてくれるアプリ。

## ステータス
MVP開発中。仕様は docs/SPEC.md、作業単位は GitHub Issue（M1〜M6）を参照。

## 開発の進め方
- 仕様の正: docs/SPEC.md
- 開発ルール: CLAUDE.md
- 作業はマイルストーン単位のIssueごとに、専用ブランチ（git worktree）で行い、PR経由でmainにマージする。

## シミュレータでの動作確認（位置情報と通知）
`<device>` はシミュレータの UDID か名前（`xcrun simctl list devices available` で確認）。他の worktree と同じシミュレータを同時に使わない。

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
2. 位置情報を「常に許可」にし、DEBUG の起動引数で「行きたい」場所を 1 件追加して起動する。
   ```sh
   xcrun simctl privacy <device> grant location-always com.example.anosa
   xcrun simctl launch <device> com.example.anosa -AnosaDebugAddPlace "東京タワー,35.658581,139.745433"
   ```
   通知の許可は simctl では付与できない。初回起動時のダイアログで「許可」をタップする。
3. 先に離れた地点に置いてから、場所の近く（500m 以内）へ動かす。
   ```sh
   xcrun simctl location <device> set 35.681236,139.767125
   xcrun simctl location <device> start --speed=50 35.681236,139.767125 35.6700,139.7550 35.6590,139.7450
   ```
   `start` の代わりに `set 35.6590,139.7450` してからアプリを前面に出してもよい（前面に来たときに現在地を取り直す）。
   シミュレータではリージョン監視（CLMonitor）が使えないため、significant-location-change（`start` での移動）か前面復帰の経路で確認する。`set` の 1 回だけでは位置更新が届かないことがある。
4. 通知を長押し（または通知センターで引き下げ）すると「行ってみる」「今日はやめる」「もう行った」が出る。「今日はやめる」は翌朝までスヌーズ、「もう行った」は「行った」に移り、一覧に反映される。「行ってみる」はマップで徒歩ルートを開く。

ログは次で見る（座標は出さない）。
```sh
xcrun simctl spawn <device> log stream --predicate 'subsystem == "com.example.anosa"' --level info
```

通知が出ないときは次を確認する。
- 静音時間（22:00〜8:00）ではないか
- 1 日 2 件の上限、同じ場所の 7 日のクールダウンに当たっていないか
- 通知が許可されているか（許可がないときは判断も記録もしない）

やり直すときは `xcrun simctl uninstall <device> com.example.anosa` してからインストールし直す（全部消すなら `xcrun simctl shutdown <device>` → `xcrun simctl erase <device>`）。

実機でのバックグラウンド位置情報（アプリを閉じた状態での通知）の確認は手動で行う。

## シミュレータでの動作確認（Watch 同期）
以下の手順は、watchOS シミュレータのランタイムがない環境で書いたため確かめていない（ビルドが通ることだけ確認済み）。`<phone>` / `<watch>` はシミュレータの UDID か名前。

1. watchOS のランタイムを入れ（Xcode の Settings > Components）、iOS と watchOS のシミュレータをペアにして起動する。
   ```sh
   xcrun simctl list pairs
   xcrun simctl pair <watch> <phone>   # ペアがなければ作る
   xcrun simctl boot <phone>
   xcrun simctl boot <watch>
   ```
2. iPhone 側は「位置情報と通知」の手順 1〜3 でインストール・場所の追加・位置の移動をする。Watch アプリは別にビルドして Watch のシミュレータに入れる。
   ```sh
   xcodebuild -project Anosa.xcodeproj -scheme AnosaWatch \
     -destination 'platform=watchOS Simulator,id=<watch>' \
     -derivedDataPath ./.derivedData build
   xcrun simctl install <watch> .derivedData/Build/Products/Debug-watchsimulator/AnosaWatch.app
   xcrun simctl launch <watch> com.example.anosa.watchkitapp
   ```
3. iPhone で位置が更新されると、Watch アプリの一覧に近い順 3 件が出る。「もう行った」を押すとすぐ一覧から消え、iPhone の一覧では「行った」に移る。コンプリケーションは文字盤の編集で「近くの行きたい場所」を追加して確かめる。

ログは `xcrun simctl spawn <phone|watch> log stream --predicate 'subsystem == "com.example.anosa" AND category == "watch"' --level info` で見る。
署名なしのシミュレータビルドでは App Group が使えず、Watch アプリとコンプリケーションでデータが共有されないことがある（コンプリケーションが「近くにはまだないよ」のままになる）。Watch 実機での確認は手動で行う。
