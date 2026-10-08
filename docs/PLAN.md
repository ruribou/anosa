# 実装計画（主要な型・構成）

仕様の正は [SPEC.md](SPEC.md)。判断の記録は [DECISIONS.md](DECISIONS.md)。この文書は M1 時点の構成と、後続マイルストーンで足すものの見通しをまとめる。

## AnosaKit（共有ロジック・Swift Package）

`AnosaKit/`。Foundation のみに依存する値型と純粋関数。M2 で `Persistence/` は SwiftData、`Search/PlaceSearch.swift` は MapKit、`UI/` は SwiftUI に依存する。platforms は iOS 26 / watchOS 26 / macOS 26（テストをホストで回すため）。

| 型 | ファイル | 役割 |
| --- | --- | --- |
| `Coordinate` | `Coordinate.swift` | 緯度経度。`distance(to:)` はハバーサイン公式（地球半径 6,371km）でメートルを返す |
| `PlaceStatus` | `Place.swift` | `wantToGo`（行きたい）/ `visited`（行った）/ `archived`（アーカイブ） |
| `Place` | `Place.swift` | 保存した場所の値型。SPEC のデータモデルの全項目（`openingHours` は任意）と `coordinate` |
| `NotificationRecord` | `Place.swift` | 通知履歴 1 件（`placeID`, `notifiedAt`） |
| `TimeOfDay` | `TimeOfDay.swift` | 日付なしの時・分。`Comparable`。`init(of:calendar:)` で Date から作る |
| `QuietHours` | `QuietHours.swift` | 静音時間帯。開始を含み終了を含まない。開始>終了は日跨ぎ、開始==終了は静音なし |
| `AnosaSettings` | `AnosaSettings.swift` | 判断エンジン・通知のパラメータを 1 か所に集約（距離 500m、1日2回、クールダウン7日、あとで3時間、静音 22:00〜8:00、古さボーナス 5m/日・最大30日、徒歩 80m/分、リージョン監視 20 件・半径 500m）。`walkingMinutes(forDistance:)`、`snoozeEnd(for:now:calendar:)` |
| `SnoozeKind` | `AnosaSettings.swift` | `today`（今日はやめる）/ `later`（あとで） |
| `OpeningHours` / `OpeningPeriod` | `OpeningHours.swift` | ユーザー任意入力の営業時間。曜日 1=日〜7=土、閉店<開店は翌日跨ぎ、開店==閉店は終日 |
| `OpeningHoursProvider` | `OpeningHours.swift` | 営業時間判定のプロトコル `isOpen(_:at:)` |
| `AlwaysOpenProvider` | `OpeningHours.swift` | 常に営業中とみなすスタブ |
| `UserInputOpeningHoursProvider` | `OpeningHours.swift` | `Place.openingHours` で判定。未設定は営業中扱い |
| `DecisionEngine` | `DecisionEngine.swift` | `placeToNotify(currentLocation:now:places:history:settings:openingHours:calendar:)` が今通知すべき 1 件を返す（なければ nil）。`priorityScore(...)` |
| `NotificationCandidate` | `DecisionEngine.swift` | 判断結果（`place`, `distanceMeters`, `walkingMinutes`） |
| `NotificationCopy` | `NotificationCopy.swift` | 通知 title 4 種、アクション名、body（`{場所名}・徒歩{n}分`）。文言の調整はこのファイルだけで行う |
| `SharedInput` / `PlaceQuery` | `SharedInput.swift` | 共有入力（URL・テキスト）と、そこから取り出した検索クエリ（`text`, `coordinate`, `sourceURL`） |
| `SharedInputParser` | `SharedInput.swift` | `query(from:)` が Apple マップ / Google マップの URL とテキストから `PlaceQuery` を作る（なければ nil） |
| `PlaceEntity` | `Persistence/PlaceEntity.swift` | `Place` の SwiftData モデル（`@Model`）。`init(_:)`・`update(from:)`・`place` で値型と相互変換 |
| `AnosaStore` | `Persistence/AnosaStore.swift` | `makeContainer(inMemory:)`。App Group（`group.com.example.anosa`）の `Anosa.store`、取れなければ既定の場所 |
| `PlaceStore` | `Persistence/PlaceStore.swift` | `@MainActor`。`save`（同 id は更新）・`places(status:)`（savedAt 降順）・`place(id:)`・`setStatus(_:for:)`・`delete(id:)` |
| `PlaceCandidate` | `Search/PlaceCandidate.swift` | 検索候補（`name`, `coordinate`, `address`）。`makePlace(sourceURL:savedAt:)` で「行きたい」の `Place` を作る |
| `PlaceSearch` | `Search/PlaceSearch.swift` | MapKit での場所解決。`candidates(for:limit:)`（検索語があれば名前検索、座標だけなら逆ジオコーディング）・`candidates(matching:near:limit:)`・`candidates(at:limit:)` |
| `PlaceResolution` | `Search/PlaceResolution.swift` | `decide(candidates:query:)` が `.single` / `.choose` / `.none` を返す純粋関数（確認なしで保存してよいかの判定）。`normalizedName(_:)` |
| `ShareFlow` | `ShareFlow.swift` | Share Extension の分岐を決める純粋関数。`firstStep(query:candidates:)` が解析結果と `PlaceResolution.decide` から最初の画面（即保存 / 候補選択）を決める。`sourceURL(query:sharedURL:)`・`sharedText(attachmentText:contentText:title:)` で sourceURL・テキストの優先順位を決める |
| `SaveCopy` | `SaveCopy.swift` | 保存まわりの文言（保存したよ。あとは忘れていいよ / 見つからない / 保存失敗） |
| `SavedConfirmationView` | `UI/SavedConfirmationView.swift` | 保存後の確認チップ（glassEffect を使う唯一の箇所）。アプリ・Share Extension で共用 |
| `RegionIdentifier` | `Location/RegionPlanner.swift` | リージョンの識別子 `place.<UUID>` の生成（`make(for:)`）と逆変換（`placeID(from:)`） |
| `RegionPlanner` / `RegionPlan` / `PlannedRegion` | `Location/RegionPlanner.swift` | `plan(currentLocation:places:monitoredIdentifiers:limit:radiusMeters:)`（`settings:` 版あり）。「行きたい」を近い順に上限件数まで選び、追加（`toAdd`）・削除（`toRemove`）の差分を返す純粋関数 |
| `LocationSnapshot` / `NearbyPlace` | `Location/LocationSnapshot.swift` | 現在地・取得時刻・近い「行きたい」場所（既定 5 件、距離・徒歩分つき）。`make(location:capturedAt:places:settings:limit:)` |
| `LocationSnapshotStore` | `Location/LocationSnapshot.swift` | スナップショットを App Group の UserDefaults（キー `locationSnapshot`）に JSON で `save` / `load`。ウィジェット・Watch が読む |
| `LocationEvaluator` | `Location/LocationEvaluator.swift` | `@MainActor`。`evaluate(currentLocation:now:)` が PlaceStore と通知履歴から DecisionEngine を呼び、候補があれば `record` で lastNotifiedAt・notifiedCount・履歴を更新して返す |
| `NotificationAction` / `PlaceNotification` | `Notifications/NotificationAction.swift` | 通知アクション（行ってみる / 今日はやめる / もう行った）の識別子と文言、カテゴリ識別子、userInfo の `placeID`、request identifier |
| `NotificationActionHandler` | `Notifications/NotificationActionHandler.swift` | `@MainActor`。`apply(_:placeID:now:store:settings:calendar:)` で今日はやめる→snoozedUntil、もう行った→visited、行ってみる→状態不変で URL。`mapsWalkingURL(for:)` |
| `NotificationHistoryStore` | `Notifications/NotificationHistoryStore.swift` | 通知履歴を App Group の UserDefaults（キー `notificationHistory`）に JSON で保存。`records()`・`append(_:now:settings:)`（保持期間より古い記録を刈る） |
| `SharedDefaults` | `Persistence/SharedDefaults.swift` | App Group の UserDefaults（取れなければ `.standard`） |
| `WatchSyncKey` / `WatchSyncContext` / `WatchVisitedMessage` | `Watch/WatchSync.swift` | WatchConnectivity の辞書（property list 型のみ）。iPhone → Watch のスナップショット（`kind: snapshot`、applicationContext とコンプリケーション用 userInfo で共用）と Watch → iPhone の「もう行った」（`kind: visited`）。不正な辞書は nil。`LocationSnapshot.refreshed(places:settings:limit:)` で同じ現在地のまま作り直す |
| `WatchVisitedLedger` / `WatchVisitedLedgerStore` | `Watch/WatchVisitedLedger.swift` | Watch で押した未反映の「もう行った」（`[UUID: Date]`）。`markVisited`・`visiblePlaces(in:limit:)`（既定 3 件）・`reconciled(with:now:)`（反映済み・1 日超を除く）。App Group の UserDefaults（キー `watchVisitedLedger`）に JSON で保存 |
| `WatchComplicationContent` | `Watch/WatchComplicationContent.swift` | コンプリケーションの表示内容（いちばん近い場所、inline・徒歩・距離の文言、場所なしの文言）と Smart Stack の `relevance` |

判断エンジンの評価順: 静音時間 → 1日上限 → 場所ごとに（ステータスが行きたい → スヌーズ → クールダウン → 距離 → 営業時間）→ 優先度スコア最小の 1 件。時刻の解釈はすべて引数の `Calendar` で行う。

テストは `AnosaKit/Tests/AnosaKitTests`（Swift Testing）。

## ターゲット構成（project.yml / XcodeGen）

| ターゲット | 種類 | プラットフォーム | 依存・埋め込み |
| --- | --- | --- | --- |
| Anosa | application | iOS（iPhone のみ） | AnosaKit、AnosaShare・AnosaWidget・AnosaWatch を埋め込み |
| AnosaShare | app-extension（Share） | iOS | AnosaKit。Web URL 1件 / テキストを受け取る |
| AnosaWidget | app-extension（WidgetKit） | iOS | — |
| AnosaWatch | application | watchOS | AnosaKit、AnosaWatchWidget を埋め込み |
| AnosaWatchWidget | app-extension（WidgetKit） | watchOS | — |

- `.xcodeproj` は生成物で git 管理しない。編集の正本は `project.yml`。各 Info.plist も `info:` から生成し、生成物をコミットする
- 署名（Team / Provisioning）は設定しない。App Group の entitlements（`group.com.example.anosa`、プレースホルダー）は M2 で Anosa・AnosaShare に追加（`Anosa/Anosa.entitlements`・`AnosaShare/AnosaShare.entitlements` は project.yml から生成してコミット）
- M1 時点の各ターゲットは骨組み（プレースホルダー UI）のみ

## iOS アプリ本体（M2）

| 型 | ファイル | 役割 |
| --- | --- | --- |
| `AppContainer` | `Anosa/AppContainer.swift` | アプリと App Intent で共有する `ModelContainer`（失敗時はインメモリ） |
| `ContentView` | `Anosa/ContentView.swift` | NavigationStack。上部 `safeAreaBar` の segmented Picker で絞り込み、toolbar の＋で手動追加の sheet |
| `PlaceListView` | `Anosa/PlaceListView.swift` | `@Query` で 1 ステータス分の一覧。スワイプでステータス変更・削除（PlaceStore 経由）。空なら ContentUnavailableView |
| `AddPlaceView` | `Anosa/AddPlaceView.swift` | `.searchable` → `PlaceSearch` の候補 → タップで保存 → 確認チップを 1 秒出して閉じる |
| `PlaceStatus`（extension） | `Anosa/PlaceStatus+Display.swift` | 一覧の絞り込み名・スワイプのボタン名・SF Symbols 名 |
| `SaveToAnosaIntent` / `AnosaShortcuts` | `Anosa/Intents/` | App Intent「Anosaに保存」（先頭候補を保存）とフレーズ「Anosaに保存」 |

## iOS アプリ本体（M3: 位置情報・通知）

| 型 | ファイル | 役割 |
| --- | --- | --- |
| `AppDelegate` | `Anosa/AppDelegate.swift` | `UIApplicationDelegateAdaptor`。didFinishLaunching で通知の delegate・カテゴリを設定し、（DEBUG のみ）起動引数の場所を追加してから `LocationService.start()`。バックグラウンド再起動でも同じ経路 |
| `LocationService` | `Anosa/Location/LocationService.swift` | `@MainActor @Observable`。権限の状態、significant-location-change、CLMonitor のリージョン入れ替え（`RegionPlanner`）、位置更新・侵入ごとのスナップショット保存と `LocationEvaluator.evaluate` → `PlaceNotifier.post` |
| `LocationGuidance` / `LocationPermissionView` | `Anosa/Location/LocationPermissionView.swift` | 権限の 2 段階の案内（使用中のみ → 常に許可 → 断られたら設定アプリへのリンク）。一覧のツールバーから出る sheet |
| `PlaceNotifier` | `Anosa/Notifications/PlaceNotifier.swift` | 通知の許可・カテゴリ（3 アクション）・即時通知。`UNUserNotificationCenterDelegate` で前面でもバナー表示、アクションを `NotificationActionHandler` に渡して保存・マップを開く |
| `DebugPlaceSeeder` | `Anosa/Debug/DebugPlaceSeeder.swift` | DEBUG のみ。`-AnosaDebugAddPlace "<名前>,<緯度>,<経度>"` で場所を 1 件追加（重複は追加しない） |

## iOS アプリ本体（M5: Watch 同期）

| 型 | ファイル | 役割 |
| --- | --- | --- |
| `WatchSyncService` | `Anosa/Watch/WatchSyncService.swift` | `@MainActor`・`WCSessionDelegate`。AppDelegate で作って activate。`LocationService` がスナップショットを保存するたびに `WatchSyncContext` を applicationContext（条件つきでコンプリケーション用 userInfo）で送る。Watch から transferUserInfo で届いた「もう行った」を反映し、スナップショットを `refreshed` で作り直して保存・送信 |

## Share Extension（M2）

| 型 | ファイル | 役割 |
| --- | --- | --- |
| `ShareViewController` | `AnosaShare/ShareViewController.swift` | principal class（UIKit）。`ShareView` を `UIHostingController` で載せ、`completeRequest` / `cancelRequest` で閉じる |
| `SharedItemLoader` | `AnosaShare/SharedItemLoader.swift` | `NSExtensionItem` から Web URL とテキストを取り出して `SharedInput` にする |
| `ShareModel` | `AnosaShare/ShareModel.swift` | `@MainActor @Observable`。解析 → 検索 → 保存 → 確認チップ 1 秒 → 閉じる。分岐は AnosaKit の `ShareFlow` で決める。PlaceStore（コンテナ）を保持 |
| `ShareView` | `AnosaShare/ShareView.swift` | 検索中は ProgressView のみ。候補選択は NavigationStack + List + `.searchable` + キャンセル |

## 検証

- 正本は `.claude/verify.conf`。手元も CI も `.claude/scripts/verify run` を実行する
  1. `xcodegen generate`
  2. `swift test`（`AnosaKit/`、ホストの macOS で実行）
  3. 5 スキームのシミュレータ向けビルド（`scripts/ci/build-scheme.sh <scheme> <ios|watchos>`、generic destination・`./.derivedData`・署名なし）
- CI は `.github/workflows/ci.yml`（macos-26、最新の Xcode 26 を選択、XcodeGen をインストールして verify run）。失敗時は verify のログを表示し artifact に上げる

## 後続マイルストーンの見通し

| M | 足すもの |
| --- | --- |
| M2 | 保存: SwiftData の永続化モデル（`Place` 値型との変換）、Share Extension の URL/テキスト受け取りと MKLocalSearch での解決・候補選択 UI、アプリ内の手動追加、保存済み一覧（行きたい / 行った / アーカイブ）、App Intent の骨組み |
| M3 | 位置情報と通知: 2 段階の権限、significant-location-change とリージョン監視（近い場所だけ登録して入れ替え）、判断エンジンの呼び出しとローカル通知・通知アクション（スヌーズ・履歴化）、App Group へのスナップショット保存（App Group の entitlements は M2 で追加済み） |
| M4 | iOS ウィジェット: small・ロック画面 accessory、App Group のスナップショットから表示、`WidgetCenter.reloadAllTimelines` |
| M5 | Watch: 近い順 3 件と「行ってみる」「もう行った」、コンプリケーション（accessory 各種・relevance）、WatchConnectivity（applicationContext）での同期 |
| M6 | 仕上げ: オンボーディング（3 画面以内）、設定（上限・静音時間・距離）、README（動作確認手順と手動作業） |

各マイルストーンの範囲は `docs/issues/m*.md`（Issue）の記載を優先する。
