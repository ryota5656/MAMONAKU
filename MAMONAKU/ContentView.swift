import SwiftUI

struct ContentView: View {
    @AppStorage("appTheme") private var appTheme: AppTheme = .dark
    @State private var currentPage: AppPage = .home
    @State private var scrollProgress: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
//            pageHeader
            TimelineScreen()
                .background(pageOffsetTracker(page: .timelineSettings))
                .tag(AppPage.timelineSettings)

//            TabView(selection: $currentPage) {
//                TimelineScreen()
//                    .background(pageOffsetTracker(page: .home))
//                    .tag(AppPage.home)
//
//                TimelineSettingScreen()
//                    .padding(.bottom, 10)
//                    .background(pageOffsetTracker(page: .timelineSettings))
//                    .tag(AppPage.timelineSettings)
//
//                ThemeSettingScreen(appTheme: $appTheme)
//                    .background(pageOffsetTracker(page: .theme))
//                    .tag(AppPage.theme)
//            }
//            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .preferredColorScheme(.dark)
        .onPreferenceChange(PageOffsetPreferenceKey.self) { offsets in
            guard let closest = offsets.min(by: { abs($0.value.minX) < abs($1.value.minX) }),
                  let width = closest.value.pageWidth,
                  width > 0
            else { return }
            let baseIndex = CGFloat(closest.key.index)
            let pageProgress = -closest.value.minX / width
            scrollProgress = max(0, min(CGFloat(AppPage.allCases.count - 1), baseIndex + pageProgress))
            let nearestIndex = Int(round(scrollProgress))
            if let page = AppPage(index: nearestIndex) {
                currentPage = page
            }
        }
    }

    private var pageHeader: some View {
        GeometryReader { proxy in
            let totalWidth = proxy.size.width
            let count = CGFloat(AppPage.allCases.count)
            let itemWidth = totalWidth / max(count, 1)
            let indicatorX = itemWidth * scrollProgress

            HStack(spacing: 0) {
                ForEach(AppPage.allCases) { page in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                            currentPage = page
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Text(page.title)
                                .font(.subheadline)
                                .fontWeight(currentPage == page ? .semibold : .regular)
                                .foregroundStyle(currentPage == page ? .primary : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay(alignment: .bottomLeading) {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: itemWidth * 0.6, height: 3)
                    .offset(x: indicatorX + (itemWidth * 0.2))
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    private func pageOffsetTracker(page: AppPage) -> some View {
        GeometryReader { geo in
            let minX = geo.frame(in: .global).minX
            let width = geo.size.width
            Color.clear
                .preference(
                    key: PageOffsetPreferenceKey.self,
                    value: [page: PageOffsetSnapshot(minX: minX, pageWidth: width)]
                )
        }
    }
}

#Preview {
    ContentView()
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "自動"
        case .light:
            return "ライト"
        case .dark:
            return "ダーク"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

enum AppPage: String, CaseIterable, Identifiable {
    case home
    case timelineSettings
    case theme

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "ホーム"
        case .timelineSettings:
            return "設定"
        case .theme:
            return "テーマ"
        }
    }

    var index: Int {
        AppPage.allCases.firstIndex(of: self) ?? 0
    }

    init?(index: Int) {
        guard index >= 0, index < AppPage.allCases.count else { return nil }
        self = AppPage.allCases[index]
    }
}

struct ThemeSettingScreen: View {
    @Binding var appTheme: AppTheme

    var body: some View {
        NavigationStack {
            Form {
                Section("外観") {
                    Picker("テーマ", selection: $appTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.title).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Text("アプリ全体のテーマを切り替えます。")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("テーマ")
        }
    }
}

private struct PageOffsetSnapshot: Equatable {
    let minX: CGFloat
    let pageWidth: CGFloat?
}

private struct PageOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: [AppPage: PageOffsetSnapshot] = [:]

    static func reduce(value: inout [AppPage: PageOffsetSnapshot], nextValue: () -> [AppPage: PageOffsetSnapshot]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
