import SwiftUI

struct AccrueLoader: View {
    @State private var scale: [CGFloat] = [0.6, 0.6, 0.6]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .frame(width: 10, height: 10)
                    .scaleEffect(scale[index])
                    .animation(Animation.easeInOut(duration: 0.6).repeatForever().delay(Double(index) * 0.2), value: scale[index])
            }
        }
        .onAppear {
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + (Double(i) * 0.2)) {
                    withAnimation {
                        scale[i] = 1.2
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation {
                            scale[i] = 0.6
                        }
                    }
                }
            }
        }
    }
}