# Firebase STG / PROD 分離手順

## 決定した方針

| 項目 | 内容 |
|------|------|
| 分離単位 | **Firebase プロジェクトを 2 つ**（同一プロジェクト内フラグは使わない） |
| PROD | `mamonaku-98306`（現行）。TestFlight / App Store はここ |
| STG | `mamonaku-stg`。ローカル Debug 検証用 |
| Xcode | **Debug → STG** / **Release → PROD** |
| TestFlight | 本番 Bundle ID + **PROD Firebase**（`.stg` は載せない） |
| Bundle ID | **Phase 1**: 両環境とも `sairyo.MAMONAKU`（すぐ動かす）<br>**Phase 2（任意）**: Debug のみ `sairyo.MAMONAKU.stg` + App Group 分離 |

### なぜ Phase 1 で Bundle ID を分けないか

`.stg` にすると App Group / Push / Live Activity Extension / Apple Developer の Capability 登録が追加で必要になり、署名エラーで開発が止まりやすい。  
Firebase プロジェクト分離だけでも Auth / Firestore / Functions / Analytics は十分分かれる。  
端末に STG と PROD を同居させたくなったら Phase 2 を実施する。

### 配信マトリクス

| 配信 | Scheme / Config | Bundle ID | Firebase |
|------|-----------------|-----------|----------|
| Xcode Run（開発） | Debug | `sairyo.MAMONAKU`（Phase 1） | STG |
| TestFlight | Release | `sairyo.MAMONAKU` | PROD |
| App Store | Release | `sairyo.MAMONAKU` | PROD |

---

## 完了済み（リポジトリ側）

1. `.firebaserc` に `prod` / `stg` エイリアス
2. `MAMONAKU/Config/Firebase/GoogleService-Info-PROD.plist` / `…-STG.plist`
3. Build Phase `Copy GoogleService-Info` で Debug→STG / Release→PROD をコピー
4. `AppEnvironment` で Cloud Functions base URL を切替
5. STG Firebase プロジェクト `mamonaku-stg` 作成、iOS アプリ登録、Auth Anonymous / Firestore 初期化

---

## 手順（再実行・追従用）

### 1. STG Firebase プロジェクト

```bash
npx -y firebase-tools@latest projects:create mamonaku-stg --display-name "MAMONAKU STG"
npx -y firebase-tools@latest use mamonaku-stg --add  # エイリアス stg
```

`.firebaserc` 例:

```json
{
  "projects": {
    "default": "mamonaku-98306",
    "prod": "mamonaku-98306",
    "stg": "mamonaku-stg"
  }
}
```

### 2. STG に iOS アプリを登録し plist 取得

```bash
npx -y firebase-tools@latest apps:create IOS \
  --project mamonaku-stg \
  --bundle-id sairyo.MAMONAKU \
  --display-name "MAMONAKU STG"

# 出力された App ID で
npx -y firebase-tools@latest apps:sdkconfig IOS <APP_ID> \
  --project mamonaku-stg \
  > MAMONAKU/Config/Firebase/GoogleService-Info-STG.plist
```

PROD の既存 plist は  
`MAMONAKU/Config/Firebase/GoogleService-Info-PROD.plist` に置く。  
アプリ本体に載る最終ファイル名は常に `GoogleService-Info.plist`（ビルド時コピー）。

### 3. STG で使うサービスを有効化

PROD と同様に最低限:

- Authentication（Anonymous）
- Cloud Firestore
- Cloud Functions（デプロイ先を `stg` に）
- Cloud Messaging（Push / Live Activity 用）

```bash
npx -y firebase-tools@latest use stg
npx -y firebase-tools@latest deploy --only firestore:rules,functions
```

PROD:

```bash
npx -y firebase-tools@latest use prod
npx -y firebase-tools@latest deploy --only firestore:rules,functions
```

### 4. Xcode（実装済みの動き）

- Debug ビルド → STG の `GoogleService-Info` + STG Functions URL
- Release ビルド → PROD の `GoogleService-Info` + PROD Functions URL
- スキームは従来どおり。TestFlight は Archive = Release = PROD

確認:

1. Debug Run → Firebase Console（STG）の Authentication / Analytics に出る
2. Archive / TestFlight → PROD に出る

### 5. Phase 2: Bundle ID 分離（任意・後続）

1. Apple Developer で App ID `sairyo.MAMONAKU.stg` を作成
2. App Group `group.sairyo.MAMONAKU.stg` を作成し、本体 + Live Activity Extension に付与
3. Push Notifications を STG App ID に有効化
4. Xcode Debug の `PRODUCT_BUNDLE_IDENTIFIER` を `.stg` に変更（Extension も連動）
5. STG 用 entitlements を Debug に割当
6. Firebase STG の iOS アプリ Bundle ID を `.stg` に更新（または作り直し）し plist 再取得
7. `AppGroup.id` を Debug / Release で分岐

---

## 運用ルール

- **本番データでデバッグしない**（Debug は常に STG）
- STG に入れた検証データは消してよい前提
- Functions / Rules の変更は **先に `firebase use stg` で検証 → `prod` にデプロイ**
- plist を手で `GoogleService-Info.plist` に上書きしない（Config 配下の STG/PROD を編集し、スクリプトに任せる）

## 残作業（任意確認）

### 実機確認（短時間）

1. Xcode で **Debug** Run
2. コンソールに `[Firebase] env=stg project=mamonaku-stg` が出る
3. [STG Authentication](https://console.firebase.google.com/project/mamonaku-stg/authentication/users) に匿名ユーザーが追加される
4. **今日の予定を配置 → 右下「完了」または「更新」** を押す（Firestore 書き込みはこの操作時のみ）
5. [STG Firestore](https://console.firebase.google.com/project/mamonaku-stg/firestore) の `users/{uid}/schedules` を確認

補足: Auth 成功だけでは Firestore には書かない。かつてはプッシュトークン取得失敗時に schedules もコミットされなかったが、トークン失敗時も予定だけは書くように修正済み。

### Functions 再デプロイ（変更時）

```bash
npx -y firebase-tools@latest deploy --only functions --project mamonaku-stg
npx -y firebase-tools@latest use prod
```

Artifact クリーンアップ警告が出た場合（任意）:

```bash
npx -y firebase-tools@latest functions:artifacts:setpolicy --project mamonaku-stg --location us-central1 --force
npx -y firebase-tools@latest functions:artifacts:setpolicy --project mamonaku-stg --location asia-northeast1 --force
```

Phase 2（任意）: Bundle ID `.stg` 分離は本手順書の「Phase 2」参照。

## 受け入れ条件

- [x] STG プロジェクト `mamonaku-stg` 作成済み
- [x] Debug ビルド成果物の `GoogleService-Info.plist` が `mamonaku-stg`
- [x] Release では PROD plist / Functions URL（`AppEnvironment`）
- [x] STG に Auth Anonymous + Firestore Rules デプロイ済み
- [x] STG を Blaze にアップグレード済み
- [x] STG へ Functions デプロイ済み
- [ ] Debug Run で STG に匿名ユーザーが作られる（実機確認）
