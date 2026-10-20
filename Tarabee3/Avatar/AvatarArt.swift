import SwiftUI

// رسم «المربع الحيّ» أشكالاً، منقولاً شكلاً بشكل من مشروع الويب (web/src/ui/avatar-art.ts) بقرار المالك — تقرير M-02.
// الهندسة: المربع ٠..١٠٠ على المحورين، وصندوق الرسم -12 -18 124 136 يترك للتلبيسات حيّزاً خارج المربع.
// الطبقات: الجسم بتدرّج المقعد ولمعته، ثم الوجه بتعبيره، ثم الرقبة والعين والرأس.
// الألوان من ملف القيم (persona وcell)، ولا لون مقعد على الوجه ولا التلبيسات.

enum AvatarGeometry {
    static let view = CGRect(x: -12, y: -18, width: 124, height: 136)
    static let simpleView = CGRect(x: 0, y: 0, width: 100, height: 100)
    static let simplifiedBelow = TokenValue.px(Tokens.Persona.Size.simplifiedBelow)
    static let blinkMin = TokenValue.px(Tokens.Persona.Size.blinkMin)
    static let shemaghDetailMin = TokenValue.px(Tokens.Persona.Size.shemaghDetailMin)
}

enum AvatarPaint {
    case body
    case color(Color)
}

struct AvatarShape {
    var path: Path
    var fill: AvatarPaint?
    var stroke: Color?
    var width: CGFloat = 0
    var opacity: Double = 1
    /// يُرسم داخل المربع وحده (اللمعة).
    var clip = false
    var part: String
}

struct AvatarDrawing {
    var view: CGRect
    var gradient: (light: Color, dark: Color)
    var shapes: [AvatarShape]
}

// MARK: - الألوان

private enum Ink {
    static let outfits = Tokens.Persona.outfitColors.map(Color.init(hex:))
    static let outfitWhite = outfits[0]
    static let outfitDark = outfits[1]
    static let sand = outfits[2]
    static let sandEdge = outfits[3]
    static let shemaghRed = outfits[4]
    static let feature = Color(hex: Tokens.Persona.featureColor)
    static let eyeWhite = Color(hex: Tokens.Persona.eyeWhite)
    static let outlineWidth = TokenValue.share(Tokens.Persona.eyeOutlineWidth) * 100
    static let shine = Color(hex: Tokens.Cell.shineColor)
    static let shineAlpha = TokenValue.number(Tokens.Cell.shineAlpha)
}

// MARK: - أدوات المسار

/// مسار SVG بالأوامر المطلقة M L Q C Z وحدها — ما تستعمله الأشكال المنقولة.
func svgPath(_ d: String) -> Path {
    var path = Path()
    var numbers: [CGFloat] = []
    var command: Character = "M"
    var token = ""

    func flushNumber() {
        if !token.isEmpty, let value = Double(token) { numbers.append(CGFloat(value)) }
        token = ""
    }
    func apply() {
        var i = 0
        func p() -> CGPoint { defer { i += 2 }; return CGPoint(x: numbers[i], y: numbers[i + 1]) }
        switch command {
        case "M":
            if numbers.count >= 2 { path.move(to: p()) }
            while i + 1 < numbers.count { path.addLine(to: p()) }
        case "L":
            while i + 1 < numbers.count { path.addLine(to: p()) }
        case "Q":
            while i + 3 < numbers.count { let c = p(); path.addQuadCurve(to: p(), control: c) }
        case "C":
            while i + 5 < numbers.count { let c1 = p(); let c2 = p(); path.addCurve(to: p(), control1: c1, control2: c2) }
        case "Z":
            path.closeSubpath()
        default:
            break
        }
        numbers = []
    }

    for ch in d {
        if "MLQCZ".contains(ch) {
            flushNumber()
            apply()
            command = ch
        } else if ch == "-" {
            flushNumber()
            token = "-"
        } else if ch == " " || ch == "," {
            flushNumber()
        } else {
            token.append(ch)
        }
    }
    flushNumber()
    apply()
    return path
}

private func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
}

/// نجمة خماسية مركزها (cx, cy).
private func star(_ cx: CGFloat, _ cy: CGFloat, outer: CGFloat, inner: CGFloat) -> Path {
    var path = Path()
    for i in 0..<10 {
        let r = i % 2 == 0 ? outer : inner
        let angle = -Double.pi / 2 + Double(i) * Double.pi / 5
        let point = CGPoint(x: cx + r * CGFloat(cos(angle)), y: cy + r * CGFloat(sin(angle)))
        if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
    }
    path.closeSubpath()
    return path
}

/// المربع: ضلعه ١٠٠ وزاويته ٢٠٪ منه (radius.cell).
let avatarBodyPath = Path(
    roundedRect: CGRect(x: 0, y: 0, width: 100, height: 100),
    cornerRadius: Radius.cell * 100,
    style: .circular
)

// MARK: - الوجه

private struct Eye: Equatable { let x: CGFloat; let y: CGFloat }
private let leftEye = Eye(x: 33, y: 46)
/// العين الغامزة، وهي التي تغطّيها عين القرصان.
private let rightEye = Eye(x: 67, y: 46)

private func line(_ d: String, _ part: String, width: CGFloat = 4) -> AvatarShape {
    AvatarShape(path: svgPath(d), stroke: Ink.feature, width: width, part: part)
}
private func dark(_ path: Path, _ part: String) -> AvatarShape {
    AvatarShape(path: path, fill: .color(Ink.feature), part: part)
}

private struct Look {
    var dx: CGFloat = 0, dy: CGFloat = 0, white: CGFloat = 11, pupil: CGFloat = 5.5, shine = false
}

private func openEye(_ eye: Eye, outline: Bool, _ look: Look = Look()) -> [AvatarShape] {
    var shapes = [
        AvatarShape(
            path: circle(eye.x, eye.y, look.white), fill: .color(Ink.eyeWhite),
            stroke: outline ? Ink.feature : nil, width: outline ? Ink.outlineWidth : 0, part: "eye-white"
        ),
        dark(circle(eye.x + look.dx, eye.y + look.dy, look.pupil), "pupil"),
    ]
    if look.shine {
        shapes.append(AvatarShape(
            path: circle(eye.x + look.dx - 2, eye.y + look.dy - 2.5, 1.8), fill: .color(Ink.eyeWhite), part: "pupil-shine"
        ))
    }
    return shapes
}

private enum Closed { case flat, happy, down }

private func closedEye(_ eye: Eye, _ shape: Closed) -> AvatarShape {
    var path = Path()
    switch shape {
    case .flat:
        path.move(to: CGPoint(x: eye.x - 10, y: eye.y))
        path.addLine(to: CGPoint(x: eye.x + 10, y: eye.y))
    case .happy:
        path.move(to: CGPoint(x: eye.x - 10, y: eye.y + 2))
        path.addQuadCurve(to: CGPoint(x: eye.x + 10, y: eye.y + 2), control: CGPoint(x: eye.x, y: eye.y - 9))
    case .down:
        path.move(to: CGPoint(x: eye.x - 10, y: eye.y - 1))
        path.addQuadCurve(to: CGPoint(x: eye.x + 10, y: eye.y - 1), control: CGPoint(x: eye.x, y: eye.y + 6))
    }
    return AvatarShape(path: path, stroke: Ink.feature, width: 4, part: "eye-closed")
}

private let smileMouth = "M36 66Q50 78 64 66"
private let openMouth = "M34 62L66 62Q66 80 50 80Q34 80 34 62Z"

private struct Face {
    let eyes: (Eye) -> [AvatarShape]
    let rest: [AvatarShape]
}

/// وجه التعبير؛ وsad «حزن الخطأ» ليس تعبيراً يُختار.
private func face(_ expression: FaceExpression?, outline: Bool) -> Face {
    let open: (Look) -> (Eye) -> [AvatarShape] = { look in { openEye($0, outline: outline, look) } }
    switch expression {
    case .smile:
        return Face(eyes: open(Look()), rest: [line(smileMouth, "mouth")])
    case .wink:
        return Face(
            eyes: { $0 == rightEye ? [closedEye($0, .happy)] : openEye($0, outline: outline) },
            rest: [line("M38 66Q52 77 64 64", "mouth")]
        )
    case .angry:
        return Face(eyes: open(Look(dy: 1)), rest: [
            line("M21 30L43 37", "brow"), line("M79 30L57 37", "brow"), line("M38 73Q50 65 62 73", "mouth"),
        ])
    case .surprised:
        return Face(eyes: open(Look(white: 12.5, pupil: 4)), rest: [
            line("M23 28Q33 21 43 28", "brow"), line("M57 28Q67 21 77 28", "brow"), dark(circle(50, 73, 6.5), "mouth"),
        ])
    case .sleepy:
        return Face(eyes: { [closedEye($0, .down)] }, rest: [line("M45 70Q50 73 55 70", "mouth")])
    case .tongue:
        return Face(eyes: open(Look()), rest: [
            AvatarShape(path: svgPath("M44 66L44 72Q50 81 56 72L56 66Z"), fill: .color(Ink.eyeWhite),
                        stroke: Ink.feature, width: 2.5, part: "tongue"),
            line("M35 64Q50 72 65 64", "mouth"),
        ])
    case .starEyes:
        return Face(
            eyes: { [AvatarShape(path: star($0.x, $0.y, outer: 12.5, inner: 5.5), fill: .color(Ink.eyeWhite),
                                 stroke: Ink.feature, width: 2.5, part: "eye-star")] },
            rest: [dark(svgPath(openMouth), "mouth")]
        )
    case .confident:
        return Face(
            eyes: { eye in
                var lid = Path()
                lid.move(to: CGPoint(x: eye.x - 11, y: eye.y))
                lid.addArc(center: CGPoint(x: eye.x, y: eye.y), radius: 11,
                           startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                lid.closeSubpath()
                return openEye(eye, outline: outline, Look(dy: 2)) + [dark(lid, "lid")]
            },
            rest: [line("M40 69Q54 74 64 62", "mouth")]
        )
    case .laughing:
        return Face(eyes: { [closedEye($0, .happy)] }, rest: [dark(svgPath(openMouth), "mouth")])
    case .excited:
        return Face(eyes: open(Look(white: 12, pupil: 6, shine: true)), rest: [
            line("M23 27Q33 20 43 27", "brow"), line("M57 27Q67 20 77 27", "brow"), dark(svgPath("M32 62Q50 86 68 62Z"), "mouth"),
        ])
    case .shy:
        return Face(eyes: open(Look(dy: 3)), rest: [
            line("M45 71Q50 75 55 71", "mouth"),
            line("M19 63L22 59M25 64L28 60M31 64L34 60", "blush", width: 2.5),
            line("M66 64L69 60M72 64L75 60M78 63L81 59", "blush", width: 2.5),
        ])
    case .thinking:
        return Face(eyes: open(Look(dx: 3, dy: -3)), rest: [
            line("M23 29Q33 23 43 29", "brow"), line("M57 33L77 33", "brow"), line("M42 71L60 67", "mouth"),
        ])
    case nil:
        return Face(eyes: open(Look(dy: 2)), rest: [
            line("M22 34L42 28", "brow"), line("M78 34L58 28", "brow"), line("M37 74Q50 64 63 74", "mouth"),
        ])
    }
}

// MARK: - التلبيسات

// الشماغ: قماش أحمر وأبيض بمربعات حمراء صغيرة، وعقال أسود مزدوج، ويسقط على جانبي المربع بانحناءة للخارج.
// المحيط قائمة قطع تعطي المسار، وبأخذ عيّنات منه المضلّع الذي تبقى المربعات داخله.
private struct Segment { let to: CGPoint; var c1: CGPoint? = nil; var c2: CGPoint? = nil }
private let shemaghStart = CGPoint(x: -6, y: 8)
private let shemaghOutline: [Segment] = [
    Segment(to: CGPoint(x: 50, y: -16), c1: CGPoint(x: -8, y: -14)),
    Segment(to: CGPoint(x: 106, y: 8), c1: CGPoint(x: 108, y: -14)),
    Segment(to: CGPoint(x: 111, y: 76), c1: CGPoint(x: 107, y: 34), c2: CGPoint(x: 109, y: 56)),
    Segment(to: CGPoint(x: 92, y: 72)),
    Segment(to: CGPoint(x: 86, y: 18), c1: CGPoint(x: 89, y: 52), c2: CGPoint(x: 87, y: 32)),
    Segment(to: CGPoint(x: 14, y: 18), c1: CGPoint(x: 50, y: 6)),
    Segment(to: CGPoint(x: 8, y: 72), c1: CGPoint(x: 13, y: 32), c2: CGPoint(x: 11, y: 52)),
    Segment(to: CGPoint(x: -11, y: 76)),
    Segment(to: shemaghStart, c1: CGPoint(x: -9, y: 56), c2: CGPoint(x: -7, y: 34)),
]

private let shemagh: (path: Path, polygon: [CGPoint]) = {
    var path = Path()
    path.move(to: shemaghStart)
    var polygon = [shemaghStart]
    var from = shemaghStart
    for segment in shemaghOutline {
        if let c1 = segment.c1, let c2 = segment.c2 {
            path.addCurve(to: segment.to, control1: c1, control2: c2)
        } else if let c1 = segment.c1 {
            path.addQuadCurve(to: segment.to, control: c1)
        } else {
            path.addLine(to: segment.to)
        }
        for i in 1...16 {
            let t = CGFloat(i) / 16, u = 1 - t
            func at(_ a: CGFloat, _ b: CGFloat?, _ c: CGFloat?, _ d: CGFloat) -> CGFloat {
                if let b, let c { return u * u * u * a + 3 * u * u * t * b + 3 * u * t * t * c + t * t * t * d }
                if let b { return u * u * a + 2 * u * t * b + t * t * d }
                return u * a + t * d
            }
            polygon.append(CGPoint(
                x: at(from.x, segment.c1?.x, segment.c2?.x, segment.to.x),
                y: at(from.y, segment.c1?.y, segment.c2?.y, segment.to.y)
            ))
        }
        from = segment.to
    }
    path.closeSubpath()
    return (path, polygon)
}()

/// هل النقطة على القماش (تقاطع الشعاع زوجياً على المحيط المأخوذ بالعيّنات).
private func onShemagh(_ x: CGFloat, _ y: CGFloat) -> Bool {
    var inside = false
    let poly = shemagh.polygon
    var j = poly.count - 1
    for i in 0..<poly.count {
        let (xi, yi, xj, yj) = (poly[i].x, poly[i].y, poly[j].x, poly[j].y)
        if (yi > y) != (yj > y), x < (xj - xi) * (y - yi) / (yj - yi) + xi { inside.toggle() }
        j = i
    }
    return inside
}

/// المربعات الحمراء مساراً واحداً: مربعات متناوبة من شبكة مركزها وسط المربع، كلّها على القماش.
private func checks(_ cell: CGFloat) -> Path {
    var path = Path()
    let view = AvatarGeometry.view
    let x0 = 50 - cell / 2 - ((62 - cell / 2) / cell).rounded(.up) * cell
    var row = 0
    var y = view.minY
    while y + cell <= view.maxY {
        var col = 0
        var x = x0
        while x + cell <= view.maxX {
            let corners = [(x, y), (x + cell, y), (x, y + cell), (x + cell, y + cell)]
            if (row + col) % 2 == 0, corners.allSatisfy({ onShemagh($0.0, $0.1) }) {
                path.addRect(CGRect(x: x, y: y, width: cell, height: cell))
            }
            col += 1
            x += cell
        }
        row += 1
        y += cell
    }
    return path
}

/// ضلع المربع الأحمر: صغير كثير من shemagh-detail-min فما فوق، وأكبر أقل دونه.
private let shemaghChecks = (detail: checks(6), simple: checks(10))

private func headShapes(_ head: HeadOutfit, side: CGFloat) -> [AvatarShape] {
    switch head {
    case .none:
        return []
    case .shemagh:
        return [
            AvatarShape(path: shemagh.path, fill: .color(Ink.outfitWhite), stroke: Ink.sandEdge, width: 1.5, part: "head-shemagh"),
            AvatarShape(path: side < AvatarGeometry.shemaghDetailMin ? shemaghChecks.simple : shemaghChecks.detail,
                        fill: .color(Ink.shemaghRed), part: "head-shemagh-check"),
            AvatarShape(path: svgPath("M-5 -1Q50 -12 105 -1"), stroke: Ink.outfitDark, width: 4.5, part: "head-agal"),
            AvatarShape(path: svgPath("M-5 6Q50 -5 105 6"), stroke: Ink.outfitDark, width: 4, part: "head-agal"),
        ]
    case .taqiyah:
        return [
            AvatarShape(path: svgPath("M10 11Q10 -13 50 -13Q90 -13 90 11Z"), fill: .color(Ink.outfitWhite),
                        stroke: Ink.sandEdge, width: 1.5, part: "head-taqiyah"),
            AvatarShape(path: svgPath("M16 3L84 3M24 -5L76 -5"), stroke: Ink.sandEdge, width: 1.5, part: "head-taqiyah-stitch"),
        ]
    case .cap:
        return [
            AvatarShape(path: svgPath("M8 12Q8 -16 50 -16Q92 -16 92 12Z"), fill: .color(Ink.outfitDark), part: "head-cap"),
            AvatarShape(path: svgPath("M50 -14L50 10"), stroke: Ink.sandEdge, width: 1.5, opacity: 0.5, part: "head-cap-seam"),
            AvatarShape(path: svgPath("M-6 14Q50 2 106 14Q50 23 -6 14Z"), fill: .color(Ink.outfitDark), part: "head-cap-brim"),
            AvatarShape(path: circle(50, -15, 3), fill: .color(Ink.sand), part: "head-cap-button"),
        ]
    }
}

private func eyeShapes(_ eye: EyeOutfit) -> [AvatarShape] {
    switch eye {
    case .none, .eyepatch: // عين القرصان تُرسم مع الوجه: تحلّ مكان العين المغطّاة
        return []
    case .glasses:
        var lenses = circle(leftEye.x, leftEye.y, 15)
        lenses.addPath(circle(rightEye.x, rightEye.y, 15))
        return [
            AvatarShape(path: lenses, stroke: Ink.outfitDark, width: 3, part: "eye-glasses"),
            AvatarShape(path: svgPath("M48 44Q50 41 52 44M18 44L0 40M82 44L100 40"), stroke: Ink.outfitDark, width: 3,
                        part: "eye-glasses-frame"),
        ]
    }
}

private var patchShapes: [AvatarShape] {
    [
        AvatarShape(path: svgPath("M-2 29L102 57"), stroke: Ink.outfitDark, width: 2.5, part: "eye-patch-strap"),
        AvatarShape(path: circle(rightEye.x, rightEye.y, 12.5), fill: .color(Ink.outfitDark), part: "eye-patch"),
    ]
}

private func neckShapes(_ neck: NeckOutfit) -> [AvatarShape] {
    guard neck == .shawl else { return [] }
    return [
        AvatarShape(path: svgPath("M-6 88Q50 104 106 88L106 100Q50 116 -6 100Z"), fill: .color(Ink.sand),
                    stroke: Ink.sandEdge, width: 1.5, part: "neck-shawl"),
        AvatarShape(path: svgPath("M66 104L80 102L84 113L70 113Z"), fill: .color(Ink.sand),
                    stroke: Ink.sandEdge, width: 1.5, part: "neck-shawl-end"),
        AvatarShape(path: svgPath("M72 113L72 116M76 113L76 116M80 113L80 116"), stroke: Ink.sandEdge, width: 1.5,
                    part: "neck-shawl-fringe"),
    ]
}

// MARK: - الرسم

/// المقاعد التي يأخذ فيها بياض العين حلقة داكنة (persona.eye-outline-teams): الأبيض دون ٣:١ عليها.
func eyeOutlined(_ team: Team) -> Bool {
    Tokens.Persona.eyeOutlineTeams.contains(team.tokenName)
}

/// الأفاتار أشكالاً من الخلف إلى الأمام.
func drawAvatar(team: Team, persona: Persona, side: CGFloat, blink: Bool = false, sad: Bool = false) -> AvatarDrawing {
    let simple = side < AvatarGeometry.simplifiedBelow
    let theFace = face(sad ? nil : persona.expression, outline: eyeOutlined(team))
    let patched = !simple && persona.eye == .eyepatch

    func eyes(_ eye: Eye) -> [AvatarShape] {
        if patched && eye == rightEye { return [] }
        let drawn = theFace.eyes(eye)
        // الرمشة تغلق العين المفتوحة؛ والمغلقة والنجمة تبقيان.
        if blink, drawn.contains(where: { $0.part == "eye-white" }) { return [closedEye(eye, .flat)] }
        return drawn
    }

    let body = AvatarShape(path: avatarBodyPath, fill: .body, part: "body")
    if simple {
        return AvatarDrawing(view: AvatarGeometry.simpleView, gradient: (team.flat, team.flat),
                             shapes: [body] + eyes(leftEye) + eyes(rightEye))
    }

    var shine = Path()
    shine.move(to: .zero)
    shine.addLine(to: CGPoint(x: 100, y: 0))
    shine.addLine(to: CGPoint(x: 100, y: 100))
    shine.closeSubpath()

    let shapes: [AvatarShape] = [body]
        + [AvatarShape(path: shine, fill: .color(Ink.shine), opacity: Ink.shineAlpha, clip: true, part: "shine")]
        + eyes(leftEye) + eyes(rightEye)
        + theFace.rest
        + neckShapes(persona.neck)
        + (patched ? patchShapes : eyeShapes(persona.eye))
        + headShapes(persona.head, side: side)
    return AvatarDrawing(view: AvatarGeometry.view, gradient: team.cell, shapes: shapes)
}
