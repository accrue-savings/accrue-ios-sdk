import SwiftUI

struct AccrueLoader: View {
    @State var loading = false
    
    var body: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(Color.gray)
                .frame(width: 20, height: 20)
                .scaleEffect(loading ? 1.5 : 0.5)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: loading)
            Circle()
                .fill(Color.gray)
                .frame(width: 20, height: 20)
                .scaleEffect(loading ? 1.5 : 0.5)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(0.2), value: loading)
            Circle()
                .fill(Color.gray)
                .frame(width: 20, height: 20)
                .scaleEffect(loading ? 1.5 : 0.5)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(0.4), value: loading)
        }
        .onAppear() {
            self.loading = true
        }
    }
}