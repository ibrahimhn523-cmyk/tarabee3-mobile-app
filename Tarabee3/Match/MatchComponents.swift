import SwiftUI

// عناصر شاشات المباراة (05-ui §٦): اللوح والمربع، وشارة المقعد ووسم «آلي»، والمؤقّت، وبطاقة السؤال وخياراته.
// شاشات المباراة واحدة في التدريب وأون لاين (القرار 0019).

// MARK: - اللوح

enum BoardMetrics {
    static let gap = TokenValue.px(Tokens.Board.gap)
    static let gapSmall = TokenValue.px(Tokens.Board.gapSmall)
}

/// اللوح بعرض الشاشة. مربعاته دون ٤٤ نقطة في ١١×١١ (05-ui §١٦): الضغطة تعاين، والاعتماد زرّ مستقل.
struct BoardView: View {
    let view: MatchView
    var preview: Square? = nil
    /// مربعات الصليب المعاين، من المحرّك (TrainingSession.previewCells).
    var previewCells: Set<Square> = []
    var previewSeat: Int? = nil
    var small = false
    var onTap: ((Square) -> Void)? = nil
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let n = view.boardSize
        let gap = small ? BoardMetrics.gapSmall : BoardMetrics.gap
        // اللوح من اليمين كالواجهة كلها (القاعدة ٨): العمود الأول يمين. وكل الأجهزة من اليمين، فاللوح واحد عند الجميع
        GeometryReader { geo in
            let side = (geo.size.width - gap * CGFloat(n - 1)) / CGFloat(n)
            VStack(spacing: gap) {
                ForEach(0..<n, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<n, id: \.self) { col in
                            let square = Square(row: row, col: col)
                            CellView(
                                owner: view.owner(row, col),
                                previewSeat: previewCells.contains(square) ? previewSeat : nil,
                                isCenter: preview == square,
                                side: side
                            )
                            .onTapGesture { onTap?(square) }
                            .accessibilityElement()
                            .accessibilityLabel(cellLabel(row: row, col: col))
                            .accessibilityAddTraits(onTap != nil ? .isButton : [])
                        }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        // بلا خلفية: المربع الفارغ في الداكن بلون surface نفسه (mode.dark-cell-empty)، فخلفية surface تخفيه
    }

    /// قارئ الشاشة: صفّه وعموده ومالكه (05-ui §١١).
    private func cellLabel(row: Int, col: Int) -> String {
        let owner = view.owner(row, col)
        let who = owner == 0 ? "فارغ" : (view.seat(owner)?.displayName ?? "")
        return "الصفّ \(row + 1)، العمود \(col + 1)، \(who)"
    }
}

/// المربع (05-ui §٦): الفارغ مسطّح، والمملوك بتدرّج المقعد ولمعته وظلّه في الفاتح، والمعاينة بلون المقعد ٤٠٪ بحدّ text.
struct CellView: View {
    let owner: Int
    var previewSeat: Int?
    var isCenter = false
    let side: CGFloat
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let radius = side * Radius.cell
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            if let team = Team(rawValue: owner) {
                shape.fill(LinearGradient(colors: [team.cell.light, team.cell.dark], startPoint: .topTrailing, endPoint: .bottomLeading))
                // اللمعة: مثلث أبيض خفيف في الطرف الأول
                Path { p in
                    p.move(to: .zero)
                    p.addLine(to: CGPoint(x: side, y: 0))
                    p.addLine(to: CGPoint(x: side, y: side))
                    p.closeSubpath()
                }
                .fill(Color(hex: Tokens.Cell.shineColor).opacity(TokenValue.number(Tokens.Cell.shineAlpha)))
                .clipShape(shape)
            } else {
                shape.fill(Color(hex: scheme == .dark ? Tokens.Mode.darkCellEmpty : Tokens.Mode.Light.cellEmpty))
            }
            if let previewSeat, let team = Team(rawValue: previewSeat) {
                shape.fill(team.flat.opacity(Alpha.preview))
                shape.strokeBorder(Palette.of(scheme).text, lineWidth: isCenter ? 2.5 : 1.5)
            }
        }
        .frame(width: side, height: side)
        .shadow(color: scheme == .light && owner != 0 ? .black.opacity(0.10) : .clear, radius: 1.5, y: 1)
        // رسم المربع لا يُعكس: الفاتح واللمعة أعلى اليمين كالأفاتار
        .environment(\.layoutDirection, .leftToRight)
    }
}

// MARK: - شارة المقعد

/// الأفاتار ٣٢، والاسم، وعدد مربعاته، وشريط بلون المقعد، ووسم «آلي» للآلي دائماً (05-ui §٦).
struct SeatBadge: View {
    let seat: SeatView
    var active = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Palette.of(scheme)
        VStack(spacing: Space.s(0)) {
            AvatarView(team: seat.team, persona: seat.persona.persona, side: TokenValue.px(Tokens.Persona.Size.badge))
            Text(verbatim: "\u{2068}\(seat.displayName)\u{2069}").font(.app(.caption, .medium))
                .foregroundStyle(palette.text).lineLimit(1)
            HStack(spacing: Space.s(0)) {
                Text(verbatim: String(seat.squares)).font(.app(.caption, .bold)).monospacedDigit()
                if seat.isBot { BotTag() }
            }
            .foregroundStyle(palette.textMuted)
            Capsule().fill(seat.team.flat).frame(height: 3)
        }
        .padding(Space.s(1))
        .frame(maxWidth: .infinity)
        // صاحب الدور بإطار لا بتعبئة: وسم «آلي» بلون surface-raised يبقى ظاهراً
        .background(active ? palette.surface : .clear, in: RoundedRectangle(cornerRadius: Radius.control))
        .overlay {
            if active { RoundedRectangle(cornerRadius: Radius.control).strokeBorder(palette.text, lineWidth: 1.5) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

/// وسم «آلي» (R-41): نصّ caption في إطار دائري بلون surface-raised.
struct BotTag: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Text(Copy.Match.bot).font(.app(.caption))
            .padding(.horizontal, Space.s(1))
            .background(Palette.of(scheme).surfaceRaised, in: Capsule())
    }
}

// MARK: - المؤقّت

/// رقم ثابت العرض وشريط يتناقص؛ وآخر خمس ثوانٍ نبض بلون text إلا عند تقليل الحركة (05-ui §٦).
struct TimerView: View {
    let deadline: Double
    let total: Double
    let now: Double
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let palette = Palette.of(scheme)
        let left = max(0, deadline - now)
        let seconds = Int((left / 1000).rounded(.up))
        let urgent = left <= 5000
        HStack(spacing: Space.s(2)) {
            Text(verbatim: String(seconds))
                .font(.custom(Tokens.Font.familyAr, fixedSize: TextLevel.timer.size).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(palette.text)
                .scaleEffect(urgent && !reduceMotion && seconds % 2 == 1 ? 1.12 : 1)
                .animation(reduceMotion ? nil : .easeInOut(duration: TokenValue.seconds(Tokens.Motion.pulse) / 2), value: seconds)
                .frame(minWidth: 44)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.surface)
                    Capsule().fill(urgent ? palette.text : palette.textMuted)
                        .frame(width: geo.size.width * CGFloat(min(1, left / total)))
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement()
        .accessibilityLabel("\(seconds) ثانية")
    }
}

// MARK: - السؤال

/// بطاقة السؤال: النصّ بمستوى h2.
struct QuestionCard: View {
    let question: QuestionView
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Text(question.text)
            .font(.app(.h2, .bold))
            .foregroundStyle(Palette.of(scheme).text)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Space.s(4))
            .background(Palette.of(scheme).surface, in: RoundedRectangle(cornerRadius: Radius.card))
    }
}

/// خيارات الإجابة (05-ui §٦): بعرض كامل؛ بعد الإرسال مقفلة، والمختار يثبت؛ وبعد الانكشاف الصحيح بحدّ سميك وعلامة صحّ،
/// والخاطئ المختار بعلامة خطأ وخافت.
struct AnswerOptions: View {
    let question: QuestionView
    var selected: AnswerChoice?
    var enabled: Bool
    var onSelect: (AnswerChoice) -> Void
    @Environment(\.colorScheme) private var scheme

    private var choices: [(AnswerChoice, String)] {
        if question.isTrueFalse { return [(.truth(true), Copy.Match.truthTrue), (.truth(false), Copy.Match.truthFalse)] }
        return (question.options ?? []).enumerated().map { (.option($0.offset + 1), $0.element) }
    }

    var body: some View {
        let palette = Palette.of(scheme)
        VStack(spacing: Space.s(2)) {
            ForEach(Array(choices.enumerated()), id: \.offset) { _, item in
                let (choice, title) = item
                let isCorrect = question.correct == choice
                let isPicked = selected == choice
                let revealed = question.correct != nil
                Button { onSelect(choice) } label: {
                    HStack(spacing: Space.s(2)) {
                        Text(title).font(.app(.body, .medium)).foregroundStyle(palette.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if revealed && isCorrect {
                            Image("icon-check").resizable().frame(width: IconSize.small, height: IconSize.small)
                        } else if revealed && isPicked {
                            Image("icon-x").resizable().frame(width: IconSize.small, height: IconSize.small)
                        } else if isPicked {
                            ProgressView().tint(palette.text)
                        }
                    }
                    .foregroundStyle(palette.text)
                    .padding(.horizontal, Space.s(3))
                    .frame(minHeight: Touch.min + Space.s(1))
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.control))
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.control).strokeBorder(
                            (revealed && isCorrect) || (!revealed && isPicked) ? palette.text : palette.line,
                            lineWidth: (revealed && isCorrect) || (!revealed && isPicked) ? 3 : 1
                        )
                    }
                    .opacity(revealed && isPicked && !isCorrect ? Alpha.disabled + 0.2 : 1)
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
                .accessibilityLabel(title)
                .accessibilityAddTraits(isPicked ? .isSelected : [])
            }
        }
    }
}
