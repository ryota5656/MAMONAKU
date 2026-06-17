import SwiftUI

struct CalendarSectionView: View {
    let primary: Color
    let secondary: Color
    let listBackground: Color
    let isCalendarSyncToggleEnabled: Bool
    let calendarSyncEnabled: Binding<Bool>
    let onTapLocked: () -> Void

    var body: some View {
        Section {
            if isCalendarSyncToggleEnabled {
                Toggle(isOn: calendarSyncEnabled) {
                    Label("標準カレンダーと同期", systemImage: "calendar.badge.clock")
                        .foregroundStyle(primary)
                }
            } else {
                Button(action: onTapLocked) {
                    HStack(spacing: 12) {
                        Label("標準カレンダーと同期", systemImage: "calendar.badge.clock")
                            .foregroundStyle(primary)
                        Spacer()
                        Text("サブスク限定")
                            .font(.caption)
                            .foregroundStyle(secondary)
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("カレンダー")
                .foregroundStyle(secondary)
        }
        .listRowBackground(listBackground)
    }
}

