import SwiftUI

/// «المربع الحيّ» بضلع side نقطة (05-ui §٦ «الأفاتار»).
/// يرمش كل ٤–٨ ثوانٍ من blink-min فما فوق، ويقفز قفزة عند ظهوره إن طُلب. وكل الحركة تسكن عند «تقليل الحركة» (R-72).
struct AvatarView: View {
    let team: Team
    let persona: Persona
    let side: CGFloat
    var hop = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    @State private var blinking = false
    @State private var lifted = false

    private var simple: Bool { side < AvatarGeometry.simplifiedBelow }

    var body: some View {
        let drawing = drawAvatar(team: team, persona: persona, side: side, blink: blinking)
        let scale = side / 100
        Canvas { context, _ in
            context.translateBy(x: -drawing.view.minX * scale, y: -drawing.view.minY * scale)
            context.scaleBy(x: scale, y: scale)
            let gradient = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [drawing.gradient.light, drawing.gradient.dark]),
                // الفاتح أعلى الطرف الأول (اليمين في واجهة من اليمين)، كمربع اللوح المملوك
                startPoint: CGPoint(x: 100, y: 0), endPoint: CGPoint(x: 0, y: 100)
            )
            for shape in drawing.shapes {
                context.drawLayer { layer in
                    layer.opacity = shape.opacity
                    if shape.clip { layer.clip(to: avatarBodyPath) }
                    switch shape.fill {
                    case .body: layer.fill(shape.path, with: gradient)
                    case .color(let color): layer.fill(shape.path, with: .color(color))
                    case nil: break
                    }
                    if let stroke = shape.stroke {
                        layer.stroke(shape.path, with: .color(stroke),
                                     style: StrokeStyle(lineWidth: shape.width, lineCap: .round, lineJoin: .round))
                    }
                }
            }
        }
        .frame(width: drawing.view.width * scale, height: drawing.view.height * scale)
        // الرسم لا يُعكس في واجهة من اليمين: العين الغامزة والشماغ في موضعهما كما في الويب.
        .environment(\.layoutDirection, .leftToRight)
        .shadow(color: scheme == .light && !simple ? .black.opacity(0.10) : .clear, radius: 2, y: 1)
        .offset(y: lifted ? -side * TokenValue.share(Tokens.Persona.hopHeight) : 0)
        .accessibilityElement()
        .accessibilityLabel(persona.spokenLabel(team: team))
        .task(id: reduceMotion) { await animate() }
    }

    private func animate() async {
        guard !reduceMotion else { blinking = false; lifted = false; return }
        if hop {
            let half = TokenValue.seconds(Tokens.Motion.base)
            withAnimation(.easeOut(duration: half)) { lifted = true }
            try? await Task.sleep(for: .seconds(half))
            withAnimation(.easeIn(duration: half)) { lifted = false }
        }
        guard side >= AvatarGeometry.blinkMin else { return }
        let range = Tokens.Persona.blinkInterval.map(TokenValue.seconds)
        let closed = TokenValue.seconds(Tokens.Motion.instant)
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: range[0]...range[1])))
            guard !Task.isCancelled else { return }
            blinking = true
            try? await Task.sleep(for: .seconds(closed))
            blinking = false
        }
    }
}
