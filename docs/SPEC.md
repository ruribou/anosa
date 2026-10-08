# Anosa 仕様書（MVP）

## プロダクトの思想（最重要。迷ったらここに戻ること）
- キャッチコピー: 「保存したら、忘れていい。」
- 「行きたい場所」をiPhoneで簡単に保存する。その後ユーザーはアプリを開かなくてよい。
- アプリ側が「近くにいる」「今行けそう」「以前から行きたいと思っていた」などを判断し、通知・ウィジェット・コンプリケーションで自然に思い出させる。
- 場所を管理するアプリではなく、「行きたい場所を実際に行く行動に変えるアプリ」。
- Apple Watchでは、アプリを開かせないことが設計の最優先事項。Watchアプリ本体は最小限でよく、通知とコンプリケーションが主役。
- 通知は「アプリが話しかけてくる」トーン。短く、軽く、押し付けない。
- アプリ名は「Anosa」（読み: あのさ）。端末上の表示名も「Anosa」。

## 技術スタック・前提
- Swift / SwiftUI。最低OS: iOS 26 / watchOS 26。Xcode 26以降のSDKでビルドする。
- 最低OSを26に固定するため、OSバージョンの #available 分岐は入れない。iOS 26 / watchOS 26で使えるAPIは素直に使う。
- 永続化: SwiftData。MVPはバックエンドなし（完全ローカル）。位置情報は端末外に出さない。アナリティクスなし。
- Xcodeプロジェクトは手書きせず、XcodeGen（project.yml）で生成する。deploymentTarget は iOS 26.0 / watchOS 26.0。生成物（.xcodeproj）はgit管理しない。
- 共有ロジックは Swift Package「AnosaKit」に切り出し、iOSアプリ・Watch・ウィジェットから共通利用する。
- Bundle ID は com.example.anosa 系のプレースホルダー。署名は設定せず、シミュレータでのビルド・テストを基準にする。
- UI文言はすべて日本語。Info.plist の位置情報利用目的文言も日本語で書く。

## デザイン方針: Liquid Glass
- iOS 26 / watchOS 26 標準のLiquid Glassを前提にする。SwiftUIの標準コンポーネント（NavigationStack、TabView、toolbar、sheet、標準ボタン）をそのまま使い、システムのガラス表現を自動で受け取る。
- ナビゲーションバー、ツールバー、タブバーに独自の背景色や不透明な背景を重ねない。
- カスタムのガラス表現が必要な箇所だけ、glassEffect と GlassEffectContainer を使う。使うのは「コンテンツの上に浮く操作系」（例: 保存後の確認チップ、地図上の浮遊ボタン）に限る。
- ガラスの上にガラスを重ねない。リストなどのコンテンツ層自体にはガラスを使わない。
- ボタンは標準の .glass / .glassProminent スタイルを優先する。
- ウィジェット/コンプリケーションは、accented / vibrant レンダリングモードで破綻しないように、widgetAccentable と renderingMode を意識して作る。背景は containerBackground を使う。
- Watchアプリ本体は標準UIのままガラス表現に任せ、独自装飾は加えない。
- アイコンはIcon Composerで作る前提とし、プレースホルダーのレイヤー構成（背景＋前景1枚）で用意する。最終デザインは人間が差し替える。
- API名や引数が不確かな場合は、推測で書かず、Xcode内のドキュメントまたはビルドで確認してから使う。

## ターゲット構成
- Anosa: iOSアプリ本体
- AnosaShare: Share Extension（保存の入口）
- AnosaWidget: iOSウィジェット（ホーム/ロック画面）
- AnosaWatch: watchOSアプリ（最小限）
- AnosaWatchWidget: watchOSウィジェット（コンプリケーション / Smart Stack）
- AnosaKit: 共有ロジック（Swift Package）
- AnosaKitTests: ユニットテスト
iOSとWatchとウィジェットの間のデータ共有はApp Groupを使い、iOS→WatchはWatchConnectivity（applicationContext）で送る。

## 機能

### 1. 保存（最小の手数で）
- Share Extension: Safari / マップ系アプリ / SNSなどから共有された URL・テキストを受け取り、MapKit（MKLocalSearch）で場所を解決して保存する。解決できなければ、ユーザーに候補を選ばせる最小UIを出す。
- アプリ内からの手動追加（場所名検索 → 保存）。
- 保存後に表示するのは「保存したよ。あとは忘れていいよ」程度の一言のみ。保存完了後は即座に閉じられること。
- App Intent（ショートカット/Siri用）で「Anosaに保存」を呼べるようにする（実装が重い場合は骨組みだけでよい）。

### 2. 判断エンジン（AnosaKit内の純粋関数。ユニットテスト必須）
入力: 現在地、現在時刻、保存済みの場所一覧、通知履歴。出力: 「今通知すべき場所」またはnil。
MVPのルール:
- 距離: 既定で徒歩圏（目安500m以内）。
- 1日の通知上限（既定2回）。
- 同じ場所の再通知は一定期間あけるクールダウン（既定7日）。
- 「今日はやめる」「あとで」を選んだ場所は一定期間スヌーズ。
- 夜間の静音時間帯（既定22時〜8時）は通知しない。
- 保存から時間が経っている場所を少し優先する（「以前から行きたかった」）。
- 営業時間: 公開APIで取得できない前提とし、OpeningHoursProvider（プロトコル）として抽象化。MVPではユーザー任意入力または未設定（常に営業中扱い）のスタブ実装にする。外部API連携はしない。
パラメータはすべて1か所の設定構造体にまとめる。

### 3. 位置情報とバックグラウンド動作
- 権限は2段階（まず「使用中のみ」→ 価値を説明した上で「常に許可」へ誘導）。
- significant-location-change と リージョンモニタリング（CLMonitor または CLCircularRegion）を併用する。
- リージョン数の上限（20程度）に対応するため、現在地に近い場所のみを登録し、位置更新のたびに登録を入れ替える。
- リージョン侵入・位置変化のたびに判断エンジンを実行し、該当すれば即時にローカル通知を出す。
- 最後の現在地と、近い場所のスナップショットをApp Groupに保存する。

### 4. 通知
- ローカル通知（UNUserNotificationCenter）。Watchには自動ミラーされるため、WatchでもiPhoneでも違和感のない短さにする。
- 通知のtitleは「近くにあるよ」系の短い語りかけ（3〜5種類のバリエーションをランダムまたは状況で出し分け）、bodyは「{場所名}・徒歩{n}分」。通知の見出しにはアプリ名「Anosa」が自動で表示される前提で文面を設計する。
  例: title「近くにあるよ」「ちょっと寄れそう」「そういえば、ここ」
- 通知アクション: 「行ってみる」（Appleマップで徒歩ルートを開く）/「今日はやめる」/「もう行った」。
- 文言バリエーションはAnosaKit内の1ファイルにまとめ、後から調整しやすくする。

### 5. ウィジェット / コンプリケーション
- iOS: 「今いちばん近い行きたい場所と距離」を表示するウィジェット（small / ロック画面用accessory）。
- watchOS: accessoryInline / accessoryCircular / accessoryRectangular / accessoryCorner のコンプリケーションで、同じ内容を表示。
- Smart Stack向けの関連度（relevance）ヒントを設定する。位置が変わったら WidgetCenter.reloadAllTimelines を呼ぶ。

### 6. Watchアプリ（最小限）
- 近い順に3件程度の一覧と、各件の「行ってみる」「もう行った」ボタンのみ。
- 「もう行った」はiPhone側に同期して、その場所を履歴扱いにする。

### 7. iOSアプリ本体（最小限）
- 保存済みの場所一覧（管理画面は凝らない。「地図アプリのような一覧管理」にしない）。
- ステータス: 行きたい / 行った（履歴）/ アーカイブ。
- 設定: 通知の上限、静音時間帯、通知距離（それぞれ控えめなUIで）。
- 初回起動時のオンボーディングは3画面以内。思想（保存したら忘れていい）を伝える。

## データモデル（目安）
Place: id, name, latitude, longitude, address, sourceURL, note, savedAt, status, lastNotifiedAt, snoozedUntil, notifiedCount, openingHours（任意）

## スコープ外（やらないこと）
- バックエンド、アカウント、クラウド同期、課金、広告
- 営業時間などの外部API連携
- AIによるおすすめ・レビュー・SNS機能
- Android、iPad専用UI

## 手動でやる必要があること（最終的にREADMEに明記する）
署名設定、App Group ID、実機でのバックグラウンド位置情報テスト、Watch実機確認、アイコンの最終デザイン差し替え。
