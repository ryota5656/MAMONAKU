import CoreGraphics

/// タイムラインの縦方向の寸法。「時刻（0 時からの分）」と「画面上の位置（pt）」を相互に変換する。
nonisolated struct TimelineLayout: Equatable, Sendable {
    /// 等倍表示での 1 時間あたりの高さ
    static let baseHourHeight: CGFloat = 80
    /// 左端の時刻ラベル列の幅
    static let timeColumnWidth: CGFloat = 52
    /// タイムラインシート左右の余白
    static let horizontalPadding: CGFloat = 20
    /// ピンチで変えられる拡大率の範囲
    static let zoomRange: ClosedRange<CGFloat> = 0.6...2.0

    /// ピンチによる拡大率
    var zoomScale: CGFloat = 1.0

    /// 現在の拡大率での 1 時間あたりの高さ
    var hourHeight: CGFloat {
        Self.baseHourHeight * zoomScale
    }

    /// 1 日（24 時間）分の高さ
    var dayHeight: CGFloat {
        hourHeight * 24
    }

    /// 0 時からの分 → タイムライン上端からの位置
    func yOffset(forMinutes minutes: Int) -> CGFloat {
        CGFloat(minutes) / 60 * hourHeight
    }

    /// 所要時間（分）→ 高さ
    func height(forDurationMinutes minutes: Int) -> CGFloat {
        CGFloat(minutes) / 60 * hourHeight
    }

    /// タイムライン上端からの位置 → 0 時からの分（0〜24 時に収める）
    func minutes(atY y: CGFloat) -> Int {
        let minutes = Int(y / hourHeight * 60)
        return max(0, min(DayTime.minutesPerDay, minutes))
    }

    /// 縦方向の移動量 → 分（リサイズ量の計算用。負の値もそのまま返す）
    func minutes(forTranslation translation: CGFloat) -> Int {
        Int(translation / hourHeight * 60)
    }

    /// 拡大率を `factor` 倍する（範囲外には出ない）。
    mutating func zoom(by factor: CGFloat) {
        zoomScale = min(max(zoomScale * factor, Self.zoomRange.lowerBound), Self.zoomRange.upperBound)
    }
}
