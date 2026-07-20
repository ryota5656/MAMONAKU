# SwiftUI Coding Rules (MVVM+Clean)

1. **構成**: Feature単位でScreen/ScreenContent/ViewModel/ViewState/Delegateに分割。
2. **Screen**: VMを保持・監視し、ライフサイクル、Alert、画面遷移などのシステム制御のみ行う。
3. **ScreenContent**: UIレイアウト専用。VMを持たずViewStateとDelegate（プロトコル）を受け取る。`#Preview`はMockDelegateを使い必ず常設。
4. **ViewModel**: ViewState（不変、Screenと1:1）の更新とロジック管理。自身をScreenContentのDelegateに準拠させアクションを直接受ける。
5. **DI/インフラ**: RepoはProtocol/Implに分離。ClientはProtocolを作らず具象クラスのみ。
6. **命名**: `[Feature]Screen` / `ScreenContent` / `ViewModel` / `ViewState` / `Delegate`

