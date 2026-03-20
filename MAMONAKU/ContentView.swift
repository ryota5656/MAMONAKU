import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            TimelineScreen()
                .background(AppColors.background(palette: themeManager.theme, environmentScheme: colorScheme))
        }
        .preferredColorScheme(themeManager.theme.preferredColorScheme)
    }
}

#Preview {
    ContentView()
        .environmentObject(SubscriptionManager())
        .environmentObject(ThemeManager())
}

class FontInfo: ObservableObject {
    @Published var fontNames: Array<String> = []
    
    init() {
        UIFont.familyNames.forEach {
            UIFont.fontNames(forFamilyName: $0).forEach {
                fontNames.append($0)
            }
        }
    }
}

struct FontView: View {
    @ObservedObject private var fontInfo = FontInfo()

    var body: some View {
        VStack {
            Text("フォント数:\(fontInfo.fontNames.count)")
            List {
                ForEach (0 ..< fontInfo.fontNames.count) {
                    Text("\(fontInfo.fontNames[$0])0123:")
                        .font(.custom(fontInfo.fontNames[$0], size: 16.0))
                }
            }
        }
    }
}

#Preview {
    FontView()
}
