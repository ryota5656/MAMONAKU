//
//  MAMONAKULiveActivityBundle.swift
//  MAMONAKULiveActivity
//
//  Created by ryota.saito on 2026/01/18.
//

import WidgetKit
import SwiftUI

@main
struct MAMONAKULiveActivityBundle: WidgetBundle {
    var body: some Widget {
        // ホーム画面ウィジェットは無効化（ロック画面 Live Activity / Dynamic Island のみ有効）
//        MAMONAKULiveActivityControl()
        MAMONAKULiveActivityLiveActivity()
    }
}
