import SwiftUI

struct CalendarMonthPickerSheet: View {
    @Binding var selectedDate: Date
    @Binding var isTwoDayView: Bool
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                DatePicker(
                    "日付を選択",
                    selection: Binding(
                        get: { selectedDate },
                        set: { newDate in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                selectedDate = Calendar.current.startOfDay(for: newDate)
                                isTwoDayView = false
                            }
                        }
                    ),
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .labelsHidden()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selectedDate = Calendar.current.startOfDay(for: Date())
                        isTwoDayView = false
                    }
                    isPresented = false
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
                    Button("完了") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview("MonthPickerSheet") {
    @Previewable @State var selectedDate = Date()
    @Previewable @State var isTwoDayView = false
    @Previewable @State var isPresented = true
    CalendarMonthPickerSheet(
        selectedDate: $selectedDate,
        isTwoDayView: $isTwoDayView,
        isPresented: $isPresented
    )
}
