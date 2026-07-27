# SwiftUI AI Coding Guidelines

**アーキテクチャ規約:** MVVM + クリーンアーキテクチャ（SwiftUI 最適化版）

本書は、AI および開発チームが SwiftUI を用いた iOS アプリケーションを、迷いなく一貫した品質で迅速に自動生成するための軽量ガイドラインです。

---

## 目次

1. [アーキテクチャ概要](#1-アーキテクチャ概要)
2. [フォルダ構成ルール](#2-フォルダ構成ルール)
3. [命名規則](#3-命名規則)
4. [UI コンポーネントの分割指針](#4-ui-コンポーネントの分割指針)
5. [View 分割の実装テンプレート](#5-view-分割の実装テンプレート)
6. [AI コード生成時の必須指示](#6-ai-コード生成時の必須指示)

---

## 1. アーキテクチャ概要

宣言的 UI に最適化した **「MVVM + クリーンアーキテクチャ」** を採用します。

### レイヤー構成とデータフロー

```
[ View (Screen) ]
       │ 監視 (Observe)
       ▼
[ ViewModel (Delegate に準拠) ] <─── ユーザーアクション（delegate.tap 等）
       │                                  │
       ▼                                  │
[ View (ScreenContent) ] ─────────────────┘
       │ ViewState を基に描画
       ▼
[ ViewState (1:1) ]
```

> 画面遷移や外部通知が必要な場合は、ViewModel から親フロー（Coordinator 等）の Delegate へ中継する。

### 各コンポーネントの定義

| コンポーネント | 責務 |
|---|---|
| **Screen** | 画面のエントリーポイント。ViewModel の実体を保持・監視する。ライフサイクル管理（`.task`）、画面遷移（Sheet / Cover）、システム系 Modifier（Alert など）の制御のみを行う。 |
| **ScreenContent** | プレビュー用プレーン UI。ViewModel そのものは持たず、不変な ViewState とイベント通知用の Delegate（インターフェース）を受け取り、描画とアクションの検知に専念する。 |
| **ViewState** | Screen と 1:1 の関係。画面表示に必要な全状態を保持する不変な構造体（`struct`）。 |
| **ViewModel** | 画面ロジックと ViewState の更新を管理。ScreenContent が要求する Delegate プロトコルに自ら準拠し、画面内のすべてのアクションを受け取る。 |
| **Delegate (Protocol)** | ScreenContent からのアクション（ボタンタップ、リフレッシュ等）を抽象化するプロトコル。プレビュー時にはモック（`PreviewDelegate`）を注入する。 |
| **UseCase** | **原則非推奨。** ViewModel が肥大化（目安 400 行以上）した際、ロジックを切り出すために導入する。 |
| **Repository** | ドメインモデルへの変換、キャッシュ制御、ビジネスルール。Protocol と Impl（実体）を分離する。 |
| **Client** | API 通信（URLSession）や DB 操作等、インフラ固有の最外殻。Protocol は作らず、具象クラスでシンプルに構築する。 |

---

## 2. フォルダ構成ルール

機能駆動型のグループ構成を採用します。共通・インフラ層は別フォルダで管理します。

```
Sources/
├── Features/                          # 機能モジュール
│   └── UserList/
│       ├── UserListScreen.swift       # ViewModel 保持・ライフサイクル・システム連携
│       ├── UserListScreenContent.swift # レイアウト本体・Preview 対象
│       ├── UserListViewModel.swift    # UserListDelegate の実装
│       ├── UserListViewState.swift
│       ├── UserListDelegate.swift     # ScreenContent からのアクション定義
│       └── Components/                # UserListSection.swift, UserListCard.swift, UserListItem.swift
├── Domain/                            # 共通モデル・抽象層
│   ├── Models/
│   └── Repositories/                  # UserRepository.swift（Protocol）
├── Infrastructure/                    # データアクセス・インフラ実装
│   ├── Repositories/                  # UserRepositoryImpl.swift
│   └── Clients/                       # APIClient.swift（実体のみ）
└── Core/                              # 共通ユーティリティ・拡張機能
```

---

## 3. 命名規則

「目的・責務・機能」＋「サフィックス」を厳格に適用します。

| レイヤー / コンポーネント | 命名パターン | 例 | 備考 |
|---|---|---|---|
| Screen（エントリーポイント） | `[Feature]Screen` | `UserListScreen` | ViewModel の監視、システム処理 |
| ScreenContent（表示本体） | `[Feature]ScreenContent` | `UserListScreenContent` | ViewState と Delegate を保持 |
| Section（画面内領域） | `[Feature][Section]Section` | `UserListActiveSection` | Card を束ねるグループ |
| Card（独立 UI コンテナ） | `[Feature][Entity]Card` | `UserListProfileCard` | 独立したカード型の UI |
| Item（最小パーツ） | `[Feature][Entity]Item` | `UserListAvatarItem` | ボタンやテキスト等の最小要素 |
| ViewModel | `[Feature]ViewModel` | `UserListViewModel` | `@Observable` 準拠、Delegate を実装 |
| ViewState | `[Feature]ViewState` | `UserListViewState` | 画面専用の状態 |
| Delegate | `[Feature]Delegate` | `UserListDelegate` | 画面アクションを ViewModel に伝えるプロトコル |
| UseCase | `[Feature][Action]UseCase` | `UserListFetchUseCase` | 必要な場合のみ作成 |
| Repository (Protocol) | `[Entity]Repository` | `UserRepository` | インターフェース定義 |
| Repository (Impl) | `[Entity]RepositoryImpl` | `UserRepositoryImpl` | 具象クラス |
| Client | `[Service]Client` | `APIClient` | 外部連携（API / DB 等）の実体クラス |

---

## 4. UI コンポーネントの分割指針

View の `body` は **1 画面あたり 100 行を超えない** ように、以下のレイヤーに従って分割・ネストします。

```
[ Screen ]          ルート View。ViewModel 保持、ライフサイクル、Alert / Sheet 管理
   │
   └── [ ScreenContent ]   レイアウト本体。ViewState と Delegate を受け取り、UI を描画（Preview 対象）
          │
          └── [ Section ]  スクロール内の意味のあるまとまり、ヘッダー / フッター
                 │
                 └── [ Card ]   特定の Entity データに紐づく、背景や枠線を持つコンテナ
                        │
                        └── [ Item ]   ラベル、アイコンなどの再利用可能な最小パーツ
```

---

## 5. View 分割の実装テンプレート

AI は、以下の **Screen → ScreenContent → Delegate → ViewModel** の構成設計に則って View を生成してください。

### ① Delegate（アクション定義プロトコル）

```swift
import Foundation

@MainActor
public protocol UserListDelegate: AnyObject {
    func userListDidRequestRefresh() async
    func userListDidSelectUser(_ user: User)
    func userListDidRequestDeleteUser(_ user: User)
}
```

### ② Screen（ViewModel 保持・システム制御）

```swift
import SwiftUI

public struct UserListScreen: View {
    @State private var viewModel: UserListViewModel

    public init(viewModel: UserListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        // ViewModel（Delegate 準拠）をそのまま渡す
        UserListScreenContent(
            state: viewModel.state,
            delegate: viewModel
        )
        .navigationTitle("ユーザー一覧")
        .task {
            await viewModel.onAppear()
        }
        // アラートなどのシステム制御は Screen で管理
        .alert(
            "ユーザーの削除",
            isPresented: Binding(
                get: { viewModel.state.isDeleteAlertPresented },
                set: { _ in }
            ),
            presenting: viewModel.state.selectedUserForDeletion
        ) { user in
            Button("削除", role: .destructive) {
                Task { await viewModel.confirmDelete() }
            }
            Button("キャンセル", role: .cancel) {
                viewModel.cancelDelete()
            }
        } message: { user in
            Text("\(user.name)を削除してもよろしいですか？")
        }
    }
}
```

### ③ ScreenContent（純粋 UI・Delegate 経由での通知）

```swift
import SwiftUI

public struct UserListScreenContent: View {
    let state: UserListViewState
    // 循環参照を防ぐため weak で保持（Delegate が AnyObject であるため可能）
    weak var delegate: UserListDelegate?

    public var body: some View {
        Group {
            switch state.screenState {
            case .idle, .loading:
                ProgressView("読み込み中...")
            case .success(let users):
                if users.isEmpty {
                    ContentUnavailableView("ユーザーが見つかりません", systemImage: "person.3")
                } else {
                    List {
                        UserListActiveSection(
                            users: users,
                            onSelect: { user in
                                delegate?.userListDidSelectUser(user)
                            },
                            onDelete: { user in
                                delegate?.userListDidRequestDeleteUser(user)
                            }
                        )
                    }
                    .refreshable {
                        await delegate?.userListDidRequestRefresh()
                    }
                }
            case .failure(let message):
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text(message)
                    Button("再試行") {
                        Task { await delegate?.userListDidRequestRefresh() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

// MARK: - Previews / Mock

// プレビュー用に空の実装（またはログ出力）を持つ Delegate を作成
final class PreviewUserListDelegate: UserListDelegate {
    func userListDidRequestRefresh() async { print("Preview: Refresh requested") }
    func userListDidSelectUser(_ user: User) { print("Preview: Selected \(user.name)") }
    func userListDidRequestDeleteUser(_ user: User) { print("Preview: Delete requested for \(user.name)") }
}

#Preview("正常系データあり") {
    UserListScreenContent(
        state: UserListViewState(
            screenState: .success([
                User(name: "山田 太郎", email: "taro@example.com"),
                User(name: "佐藤 花子", email: "hanako@example.com")
            ])
        ),
        delegate: PreviewUserListDelegate()
    )
}

#Preview("ローディング中") {
    UserListScreenContent(
        state: UserListViewState(screenState: .loading),
        delegate: PreviewUserListDelegate()
    )
}
```

### ④ ViewModel（Delegate プロトコルへの準拠）

```swift
import Foundation
import Observation

@Observable
@MainActor
public final class UserListViewModel: UserListDelegate {
    // MARK: - State
    public private(set) var state = UserListViewState()

    // MARK: - Dependencies
    private let userRepository: UserRepository

    public init(userRepository: UserRepository) {
        self.userRepository = userRepository
    }

    // ライフサイクルイベント
    public func onAppear() async {
        guard state.screenState == .idle else { return }
        await fetchUsers()
    }

    // MARK: - UserListDelegate 実装

    public func userListDidRequestRefresh() async {
        state.isRefreshing = true
        await fetchUsers()
        state.isRefreshing = false
    }

    public func userListDidSelectUser(_ user: User) {
        // 必要に応じて画面遷移コーディネーターなどに通知
        print("Detail Transition for: \(user.name)")
    }

    public func userListDidRequestDeleteUser(_ user: User) {
        state.selectedUserForDeletion = user
        state.isDeleteAlertPresented = true
    }

    // MARK: - Internal Actions

    public func confirmDelete() async {
        guard let user = state.selectedUserForDeletion else { return }
        do {
            try await userRepository.deleteUser(id: user.id)
            await fetchUsers()
        } catch {
            state.screenState = .failure(error.localizedDescription)
        }
        state.selectedUserForDeletion = nil
        state.isDeleteAlertPresented = false
    }

    public func cancelDelete() {
        state.selectedUserForDeletion = nil
        state.isDeleteAlertPresented = false
    }

    private func fetchUsers() async {
        if !state.isRefreshing {
            state.screenState = .loading
        }
        do {
            let users = try await userRepository.fetchUsers()
            state.screenState = .success(users)
        } catch {
            state.screenState = .failure("エラーが発生しました: \(error.localizedDescription)")
        }
    }
}
```

---

## 6. AI コード生成時の必須指示

AI がコードを出力する場合、以下の規約を遵守できているか **自己チェックしてから提示** してください。

| 規約 | 内容 |
|---|---|
| **暗黙の画面遷移の禁止** | View 内で直接 `NavigationLink(destination: ...)` を埋め込んではならない。画面遷移が必要な場合は必ず Delegate（または Router / Coordinator パターン）を経由し、外部に通知すること。 |
| **プレビュー（`#Preview`）の常設** | 全ての ScreenContent に `#Preview` を配置し、`PreviewDelegate` のようにプレビュー用のクリーンなモックデータとモック Delegate を用意して動作確認できるようにすること。 |
| **安全なスレッド処理** | UI の表示更新を伴うすべての ViewModel や Delegate に `@MainActor` を付与し、非同期通信（Task 処理）中のメインスレッド以外からの更新を防止すること。 |
| **状態の単一ソース** | 各画面の状態は、その Screen と 1:1 の ViewState 構造体に一本化し、細切れの `@State` や個別の `@Published` を ViewModel 内に分散させないこと。 |
| **テスト容易性の確保** | ViewModel が Repository などのデータストアを呼び出す際は、必ず Protocol 経由とし、具体的なインスタンスの生成ロジックを直接イニシャライザに記述しない（DI を採用すること）。 |
