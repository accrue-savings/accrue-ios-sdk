import SwiftUI

struct AccrueLoader: View {
    @State var loading = false
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.gray)
                .frame(width: 10, height: 10)
                .scaleEffect(loading ? 1.2 : 0.8)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: loading)
            Circle()
                .fill(Color.gray)
                .frame(width: 10, height: 10)
                .scaleEffect(loading ? 1.2 : 0.8)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(0.2), value: loading)
            Circle()
                .fill(Color.gray)
                .frame(width: 10, height: 10)
                .scaleEffect(loading ? 1.2 : 0.8)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(0.4), value: loading)
        }
        .onAppear() {
            self.loading = true
        }
    }
}