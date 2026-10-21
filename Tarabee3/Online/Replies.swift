import SwiftUI

/// الردود الجاهزة (R-34): شرائح دائرية في S-10، والمرسَل يظهر فوق شارة مرسله ثانيتين، ثم مقفلة ثلاث ثوانٍ (05-ui §٦).
/// الخادم ينقل رقم الرد وحده، ولا يحفظه.
struct RepliesRow: View {
    let session: any MatchSession

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s(1)) {
                ForEach(0..<Copy.Online.replies.count, id: \.self) { i in
                    Button { session.sendReply(i) } label: { ReplyChip(text: Copy.Online.replies[i]) }
                        .buttonStyle(.plain)
                        .disabled(!session.canReply)
                        .opacity(session.canReply ? 1 : Alpha.disabled + 0.25)
                }
            }
        }
        .frame(height: Touch.min)
    }
}

/// شريحة الرد: دائرية بسطح surface-raised.
struct ReplyChip: View {
    let text: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Palette.of(scheme)
        Text(text).font(.app(.small, .medium)).foregroundStyle(palette.text).lineLimit(1)
            .padding(.horizontal, Space.s(2))
            .padding(.vertical, Space.s(1))
            .background(palette.surfaceRaised, in: Capsule())
    }
}
