import SwiftUI

/// 表示する日をカレンダーから選ぶシート。
struct TimelineDatePickerSheet: View {
    let selectedDate: Date
    let onSelectDate: (Date) -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                DatePicker(
                    "日付を選択",
                    selection: Binding(
                        get: { selectedDate },
                        set: { select($0) }
                    ),
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .labelsHidden()

                Button {
                    select(Date())
                    onClose()
                } label: {
                    Label("今日へ移動", systemImage: "calendar.badge.clock")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("日付を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了", action: onClose)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func select(_ date: Date) {
        withAnimation(AppAnimation.stateChange) {
            onSelectDate(Calendar.current.startOfDay(for: date))
        }
    }
}

#Preview("TimelineDatePickerSheet") {
    @Previewable @State var selectedDate = Date()
    TimelineDatePickerSheet(
        selectedDate: selectedDate,
        onSelectDate: { selectedDate = $0 },
        onClose: {}
    )
}
