# MAMONAKU：スタック型 Live Activity 自動更新 機能要件定義

> 本ドキュメントは **目指す仕様（理想要件）** です。現行実装との差分は末尾「実装ギャップ」に記載します。

## 1. 機能概要

ユーザーがアプリ内で作成・編集したタイムライン予定を、**ローカル（Realm）と Firestore の両方に保存**する。  
Firestore 上の予定変更を Cloud Functions が監視し、Cloud Tasks を登録・更新する。予定開始時刻に到達すると、アプリがバックグラウンド／終了状態でも **Cloud Tasks → APNs（ActivityKit Push）** で Live Activity がローテーションされる。

表示内容は **「直近の予定1つ（プライマリ）」＋「次に控える予定最大2つ（スタック）」の計最大3件**。

- **無料プラン**: Live Activity 利用可。ロック画面は直近 **1件のみ**。自動ローテーションあり（次の1件へ）
- **PLUS プラン**: スタック表示ON時は最大 **3件**。OFFなら無料と同じ1件

### プラン別機能表

| 機能 | 無料 | PLUS |
| --- | --- | --- |
| タイムライン編集・Stock | ○ | ○ |
| Live Activity ON/OFF | ○ | ○ |
| ロック画面表示 | 直近1件 | 最大3件スタック（設定でON） |
| Cloud Tasks → APNs 自動更新 | ○ | ○ |
| 完了 / 更新での Firestore 同期 | ○ | ○ |
| バッファ通知・カレンダー同期・有料テーマ・優先度 | × | ○ |

### 設計方針（負荷・複雑さ）

- 編集中はローカルのみ更新し、**確定操作のときだけ** Firestore へ送る
- バックグラウンド遷移ではクラウド処理を行わない（不安定化を避ける）
- Cloud Functions は「Firestore 予定の差分 → Tasks 再構築 → APNs」に責務を限定する
- クライアントは表示用 ContentState の組み立てと、確定時の予定アップロードに責務を限定する

---

## 2. UI/UX 要件（Live Activity 表示仕様）

### 2.1. Lock Screen / Banner

- **左側（プライマリ）**: タイトル、開始までのカウントダウン（`Text(timerInterval:)`）
- **右側（スタック最大2）**: 相対時間 or 開始時刻、タイトル
- テーマ色は使わない（システム色）

### 2.2. Dynamic Island

- Compact / Expanded / Minimal でプライマリを表示

### 2.3. ローテーション

プライマリのカウントダウンが **0:00（開始時刻到達）** になった瞬間、APNs update により:

1. 予定 A が消える
2. 予定 B がプライマリへ昇格し、次のカウントダウンが始まる
3. 以降のスタックが繰り上がり、必要なら次予定が補充される
4. 最後なら Live Activity を end する

---

## 3. データ構造要件

### 3.1. アプリ内予定モデル

#### `TimelineItem`

| 項目 | 型 | 説明 |
| --- | --- | --- |
| id | UUID | 識別子（Firestore DocumentID にも用いる） |
| title | String | 予定名 |
| durationMinutes | Int | 所要時間（分） |
| startMinutes | Int? | 0 時起算の開始分。Stock は `nil` |
| dropDate | Date? | 配置日。Stock は `nil` |
| isCompleted | Bool | 完了フラグ |
| priority | TaskPriority | low / medium / high |
| isAllDay | Bool | 終日（Live Activity 対象外） |
| bufferMinutes | Int? | 個別バッファ（任意） |

- Stock: `dropDate == nil`
- Live Activity 対象: **当日配置・非終日・開始時刻あり**

### 3.2. Live Activity 表示データ

`ContentState.schedule: [ActivityTaskItem]`（最大 3 件）

#### `ActivityTaskItem`

| 項目 | 型 |
| --- | --- |
| nextTitle | String |
| nextStartDate | Date? |
| nextEndDate | Date? |
| countdownStartDate | Date? |
| remainingTimeShort | String |
| bufferMinutes | Int? |

#### Attributes

```swift
struct MAMONAKULiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var schedule: [ActivityTaskItem]
    }
    var name: String // 例: "timeline-stack"
}
```

### 3.3. 二重保存の役割分担

| 保存先 | 役割 |
| --- | --- |
| ローカル（Realm） | 編集・表示の作業用データ。オフラインでも操作可能 |
| Firestore | クラウド同期用の予定。Functions / Tasks の入力 |

編集中はローカルのみ変更する。  
**完了ボタンまたは更新ボタン押下時**に、ローカルの当日対象予定を Firestore へ upsert / 削除反映する。

### 3.4. Firestore 構造（目指す形）

```
users
 └── {firebaseUid}
      ├── schedules
      │    └── {timelineItemId}
      │         ├── title: string
      │         ├── durationMinutes: number
      │         ├── startMinutes: number | null
      │         ├── dropDate: timestamp | null   // 日付のみ（当日 0:00）
      │         ├── startDate: timestamp         // 開始の実時刻
      │         ├── endDate: timestamp           // 終了の実時刻
      │         ├── isCompleted: boolean
      │         ├── priority: number
      │         ├── isAllDay: boolean
      │         ├── bufferMinutes: number | null
      │         ├── updatedAt: timestamp
      │         └── deleted: boolean          // 論理削除でも可
      │
      └── devices
           └── {deviceId}
                ├── fcmToken
                ├── liveActivityToken
                ├── apnsTopic
                └── updatedAt

liveActivityDevices（運用補助・任意）
 └── {deviceId}
      ├── firebaseUid
      ├── scheduledTaskNames[]
      └── updatedAt
```

> 予定の正本アップロード先は `users/{uid}/schedules`。  
> Cloud Tasks の管理情報は `liveActivityDevices` 等に分離してよい。

---

## 4. 同期・更新トリガー（クライアント）

### 4.1. Firebase へ送るタイミング（必須）

次の **いずれか押下時のみ** Firestore へ予定を反映する。

1. **編集完了ボタン**（`TaskSheetTabBarView` の completeEditingButton）
2. **Live Activity 更新ボタン**（`TaskSheetTabBarView` の refreshLiveActivityButton）

押下時の処理概要:

1. ローカル予定を確定保存（Realm）
2. 当日の Live Activity 対象予定を Firestore `schedules` に反映（追加・更新・削除）
3. 必要ならローカル Live Activity を即時更新（フォアグラウンド表示用）
4. （トークン類が未送信なら）device ドキュメントも更新

### 4.2. やってはいけないこと

- **アプリのバックグラウンド移行時に同期・commit しない**
- 予定を動かすたびに都度 Firestore 書き込みしない（編集中はローカルのみ）

### 4.3. 編集中のローカル挙動

- 追加・移動・リサイズ・削除は Realm に反映してよい
- `markPending` 相当の「未同期」状態を UI 上で示してよい（任意）
- 未同期のまま完了/更新を押さなければ、クラウド側 Tasks は古いまま残る（仕様として許容。明示操作で最新化する）

---

## 5. Cloud Functions / Cloud Tasks 要件

### 5.1. Firestore 監視

`users/{uid}/schedules` の作成・更新・削除（または `deleted` 更新）を Cloud Functions が監視する。

監視時の責務:

1. 対象ユーザーの有効予定一覧を取得
2. Live Activity 表示用ウィンドウ（最大 3 件）とローテーション時刻列を再計算
3. **既存 Cloud Tasks をキャンセル**
4. 新しい Cloud Tasks を登録（各 switchAt）
5. 必要なら直近表示用の APNs update を送る（初回反映・大幅変更時）

### 5.2. 変更・削除時の Tasks

予定の変更・削除のたびに（＝ schedules 書き込みのたびに） Tasks を作り直す。

- 部分パッチより **全キャンセル → 再登録** を基本とする（実装を単純にする）
- 書き込み頻度はクライアント側で「完了/更新時のみ」に制限するため、負荷は抑えられる

### 5.3. Tasks 実行時

Cloud Tasks 発火時:

1. 最新の schedules から「今表示すべき schedule（最大3件）」を組み立てる  
   （実行直前に再計算し、古い Task が残っていても安全にする）
2. APNs で Live Activity を update または end
3. プライマリのカウントダウンが 0 になったタイミングで、次予定のカウントダウンが始まる ContentState を送る

### 5.4. Push

- ActivityKit Push（update / end）
- 毎秒 Push しない
- カウントダウン描画は OS の timerInterval に委譲

---

## 6. 例外・エッジケース

| ケース | 扱い |
| --- | --- |
| 予定 0 件 | Live Activity end。Tasks 全キャンセル |
| 1〜2 件 | 存在するスロットのみ表示 |
| 終日 / 日付違い | 対象外 |
| ネットワーク失敗（完了/更新時） | ローカルは保持。エラー表示し、再タップで再送 |
| Token 未取得 | device 情報を保留し、取得後に再送可能にする |
| 古い Task が発火 | 実行時に Firestore 最新予定で再計算。不要なら no-op |
| 同時刻開始 | startMinutes 昇順 |

---

## 7. 画面との対応

```
MainTabView
 └─ TaskSheetTabBarView
      ├─ 編集中: completeEditingButton
      │     → 編集終了 + Firestore 予定同期（本要件の同期トリガー）
      └─ 通常: refreshLiveActivityButton
            → Firestore 予定同期 + Live Activity 手動更新
```

- バックグラウンド遷移: **何もしない**
- フォアグラウンド復帰: 必須処理なし（任意で表示の overdue チェックのみ可。クラウド書き込みはしない）

---

## 8. 実装ギャップ（現行コードとの差）

| 理想要件 | 現行実装（本変更後） |
| --- | --- |
| 予定をローカル + Firestore の両方へ保存 | `TimelineFirestoreSyncService` が完了/更新時に `users/{uid}/schedules` へ全置換 |
| Firestore 予定反映後に Functions が Tasks 登録 | `liveActivityCommands/rebuild` 監視 → Tasks 再登録 + APNs |
| 完了ボタンで Firebase 同期 | `completeEditingAndSyncLiveActivity()` |
| 更新ボタンで Firebase 同期 | `commitPendingLiveActivitySync(force: true)` |
| バックグラウンドで何もしない | `scenePhase == .background` では同期しない |

---

## 9. 二重管理・競合の取り扱い（必須ルール）

ローカルと Firestore の両方に予定を持つが、**同時に双方を正本にしない**。

| ルール | 内容 |
| --- | --- |
| R1 | 編集中の正本は常にローカル（Realm） |
| R2 | Firestore への予定書き込みは「完了」「更新」押下時のみ |
| R3 | Cloud Functions は Firestore を読んで Tasks / APNs を作るだけ。端末の予定へは書き戻さない |
| R4 | バックグラウンド遷移では同期しない |
| R5 | 同期は当日の Live Activity 対象予定を **全置換（upsert + 不要ドキュメント削除）** する |
| R6 | 古い Cloud Tasks が発火しても、実行時に Firestore 最新予定で再計算し、不要なら no-op |
| R7 | 同期失敗時はローカルを保持し、再タップで再送できること |

このルールにより、双方向同期のような重い競合解決は不要。  
「最後に完了/更新した内容がクラウドに残る」で足りる。

完了前にアプリを終了した場合、クラウド側は古いまま残る。これは仕様として許容する（次回の完了/更新で上書きされる）。
