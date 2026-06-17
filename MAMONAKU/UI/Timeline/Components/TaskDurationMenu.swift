import SwiftUI

struct TaskDurationMenu: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var minutes: Int

    var body: some View {
        Menu {
            Picker("", selection: $minutes) {
                ForEach(Array(stride(from: 5, through: 480, by: 5)), id: \.self) { m in
                    Text("\(m) min")
                        .foregroundStyle(AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme))
                        .font(.system(size: 10))
                        .tag(m)
                }
            }
            .tint(.primary)
        } label: {
            Text("\(minutes) min")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
        }
    }
}

#Preview("TaskDurationMenu") {
    @Previewable @State var minutes = 30
    TaskDurationMenu(minutes: $minutes)
        .padding()
        .environmentObject(ThemeManager())
}

