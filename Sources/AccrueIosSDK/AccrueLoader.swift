import SwiftUI

@available(iOS 13.0, macOS 10.15, *)
struct AccrueLoader: View {
    @State var loading = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.gray)
                .frame(width: 10, height: 10)
                .scaleEffect(loading ? 1.4 : 1)
                .animation(
                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: loading)
            Circle()
                .fill(Color.gray)
                .frame(width: 10, height: 10)
                .scaleEffect(loading ? 1.4 : 1)
                .animation(
                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(0.2),
                    value: loading)
            Circle()
                .fill(Color.gray)
                .frame(width: 10, height: 10)
                .scaleEffect(loading ? 1.4 : 1)
                .animation(
                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(0.4),
                    value: loading)
        }
        .onAppear {
            self.loading = true
        }
    }
}
