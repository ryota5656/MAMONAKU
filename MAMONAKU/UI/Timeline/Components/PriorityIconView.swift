import SwiftUI

struct PriorityIconView: View {
    let priority: TaskPriority
    var color: Color = .secondary
    var size: CGFloat = 14

    var body: some View {
        ZStack {
            Circle()
                .stroke(color, lineWidth: 1)
            Image(systemName: priority.iconName)
                .font(.system(size: size * 0.55))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}

#Preview("PriorityIconView") {
    HStack(spacing: 12) {
        PriorityIconView(priority: .low, color: .secondary, size: 22)
        PriorityIconView(priority: .medium, color: .blue, size: 22)
        PriorityIconView(priority: .high, color: .orange, size: 22)
    }
    .padding()
}

