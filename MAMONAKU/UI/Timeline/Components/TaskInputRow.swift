import SwiftUI
import UIKit

struct TaskInputRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let isSubscribed: Bool
    @Binding var title: String
    @Binding var durationMinutes: Int
    @Binding var priority: TaskPriority
    var isTaskInputFocused: FocusState<Bool>.Binding
    let onSubmit: (String, Int, TaskPriority) -> Void

    /// Plus 押下後も UITextField に first responder を戻すためのトリガー
    @State private var retainFocusTick = 0

    var body: some View {
        HStack(spacing: 8) {
            if isSubscribed {
                Menu {
                    Picker("優先度", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.rawValue) { p in
                            Label(p.displayName, systemImage: p.iconName)
                                .tag(p)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    PriorityIconView(
                        priority: priority,
                        color: priorityColor(for: priority),
                        size: 22
                    )
                }
            } else {
                PriorityIconView(
                    priority: .low,
                    color: priorityColor(for: .low),
                    size: 22
                )
            }

            KeepFocusTextField(
                text: $title,
                placeholder: "タスクを追加",
                isFocused: isTaskInputFocused,
                retainFocusTick: retainFocusTick,
                onSubmit: submitIfPossible
            )
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .contentShape(Rectangle())

            TaskDurationMenu(minutes: $durationMinutes)

            Button {
                submitIfPossible()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(canAdd ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(!canAdd)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var canAdd: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitIfPossible() {
        guard canAdd else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = isSubscribed ? priority : TaskPriority.low
        onSubmit(trimmed, durationMinutes, p)
        title = ""
        // キーボードを閉じさせず、連続入力できるようにフォーカスを維持
        isTaskInputFocused.wrappedValue = true
        retainFocusTick &+= 1
    }

    private func priorityColor(for p: TaskPriority) -> Color {
        switch p {
        case .low:
            return AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme)
        case .medium:
            return AppColors.accent(palette: themeManager.theme, environmentScheme: colorScheme)
        case .high:
            return AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme)
        }
    }
}

/// Return / 確定でも first responder を手放さない TextField
private struct KeepFocusTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var isFocused: FocusState<Bool>.Binding
    var retainFocusTick: Int
    let onSubmit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.placeholder = placeholder
        textField.font = .systemFont(ofSize: 12)
        textField.returnKeyType = .next
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.adjustsFontForContentSizeCategory = true
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.setContentHuggingPriority(.required, for: .vertical)
        textField.setContentCompressionResistancePriority(.required, for: .vertical)
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self
        context.coordinator.textField = uiView

        if uiView.text != text {
            uiView.text = text
        }

        // retainFocusTick 更新時だけ強制的にフォーカスを戻す（Plus 押下など）
        if context.coordinator.lastRetainFocusTick != retainFocusTick {
            context.coordinator.lastRetainFocusTick = retainFocusTick
            DispatchQueue.main.async {
                _ = uiView.becomeFirstResponder()
            }
            return
        }

        // FocusState の false で resign しない（タップ直後の更新と競合してキーボードが開かないため）
        if isFocused.wrappedValue, !uiView.isFirstResponder {
            DispatchQueue.main.async {
                guard self.isFocused.wrappedValue else { return }
                _ = uiView.becomeFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: KeepFocusTextField
        weak var textField: UITextField?
        var lastRetainFocusTick = 0

        init(parent: KeepFocusTextField) {
            self.parent = parent
        }

        @objc func editingChanged(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            // false でキーボードを閉じない（連続入力）
            return false
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !parent.isFocused.wrappedValue {
                parent.isFocused.wrappedValue = true
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if parent.isFocused.wrappedValue {
                parent.isFocused.wrappedValue = false
            }
        }
    }
}

#Preview("TaskInputRow - subscribed") {
    struct Container: View {
        @State var title = "タスク"
        @State var duration = 30
        @State var priority: TaskPriority = .medium
        @FocusState var focused: Bool

        var body: some View {
            TaskInputRow(
                isSubscribed: true,
                title: $title,
                durationMinutes: $duration,
                priority: $priority,
                isTaskInputFocused: $focused,
                onSubmit: { _, _, _ in }
            )
            .padding()
            .environmentObject(ThemeManager())
        }
    }

    return Container()
}
