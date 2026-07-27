import SwiftUI

struct TypewriterText: View {
    let text: String
    let interval: TimeInterval
    @State private var visibleCount = 0
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        Text(String(text.prefix(visibleCount)))
            .onAppear { startAnimation() }
            .onChange(of: text) { _, _ in startAnimation() }
            .onDisappear {
                animationTask?.cancel()
                animationTask = nil
            }
    }

    private func startAnimation() {
        animationTask?.cancel()
        visibleCount = 0
        animationTask = Task {
            let characters = Array(text)
            for index in 0...characters.count {
                if Task.isCancelled { return }
                await MainActor.run { visibleCount = index }
                let sleepNanos = UInt64(interval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: sleepNanos)
            }
        }
    }
}

#Preview("TypewriterText") {
    TypewriterText(text: ">>> Next event in...", interval: 0.05)
        .font(.system(size: 10, weight: .semibold))
        .padding()
}

