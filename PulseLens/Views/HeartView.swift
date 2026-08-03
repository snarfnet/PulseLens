import SwiftUI

/// 拍動ごとにドクンと脈打つ心臓アイコン。beatTickが変わると1回スケールする。
struct HeartView: View {
    let beatTick: Int
    let color: Color
    @State private var scale: CGFloat = 1

    var body: some View {
        Image(systemName: "heart.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.6), radius: 10)
            .scaleEffect(scale)
            .onChange(of: beatTick) { _, _ in
                withAnimation(.easeOut(duration: 0.08)) { scale = 1.25 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                    withAnimation(.easeIn(duration: 0.28)) { scale = 1 }
                }
            }
    }
}
