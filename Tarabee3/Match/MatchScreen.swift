import SwiftUI

/// شاشات المباراة (S-09 إلى S-11، والعرض، وS-14) تملأ الشاشة بلا زرّ رجوع، والمحرّك ينقل بينها (05-ui §٨).
/// في التدريب يحكمها المحرّك على الجهاز؛ وأون لاين (M-06) يحكمها الكائن والشاشات نفسها.
struct MatchScreen: View {
    let session: TrainingSession
    var onPlayAgain: () -> Void
    var onExit: () -> Void

    @State private var tab = Tab.board
    @State private var confirmExit = false
    @Environment(\.colorScheme) private var scheme

    enum Tab: Hashable { case board, question }

    var body: some View {
        let palette = Palette.of(scheme)
        Group {
            if let view = session.view {
                if view.phase.kind == "ended" {
                    ResultScreen(view: view, onPlayAgain: onPlayAgain, onHome: onExit)
                } else {
                    TimelineView(.periodic(from: .now, by: 0.2)) { _ in
                        playing(view, palette)
                    }
                }
            } else if session.failed {
                VStack(spacing: Space.s(4)) {
                    StatusBanner(kind: .error, text: Copy.Match.packMissing)
                    Button(Copy.Match.home, action: onExit).appButton(.secondary)
                }
                .padding(Space.s(3))
            } else {
                ProgressView().tint(palette.text)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
        .sheet(isPresented: $confirmExit) {
            VStack(alignment: .leading, spacing: Space.s(4)) {
                Text(Copy.Match.exitTitle).font(.app(.h2, .bold)).foregroundStyle(palette.text)
                Text(Copy.Match.exitConfirm).font(.app(.body)).foregroundStyle(palette.text)
                Spacer(minLength: 0)
                Button(Copy.Match.exit) { confirmExit = false; onExit() }.appButton(.danger)
                Button(Copy.Settings.cancel) { confirmExit = false }.appButton(.plain).frame(maxWidth: .infinity)
            }
            .padding(Space.s(4))
            .appBackground()
            .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private func playing(_ view: MatchView, _ palette: Palette) -> some View {
        let now = session.now
        let mine = session.isMyTurn
        let kind = view.phase.kind
        VStack(spacing: Space.s(3)) {
            header(view, palette)

            if kind == "countdown" {
                CountdownView(until: view.phase.until ?? now, now: now)
            } else if kind == "answering" && mine, let round = view.round {
                // S-09 · دورك
                statusLine(Copy.Match.yourTurn, palette)
                TimerView(deadline: round.deadline, total: MatchRules.answerMs, now: now)
                ScrollView {
                    VStack(spacing: Space.s(3)) {
                        QuestionCard(question: round.question)
                        AnswerOptions(question: round.question, selected: session.sentAnswer,
                                      enabled: session.sentAnswer == nil) { session.answer($0) }
                    }
                }
            } else if kind == "choosing" && mine, let deadline = view.phase.deadline {
                // S-11 · اختيار المربع
                statusLine(Copy.Match.chooseSquare, palette)
                TimerView(deadline: deadline, total: MatchRules.chooseMs, now: now)
                BoardView(view: view, preview: session.preview, previewSeat: TrainingSession.mySeat) { session.select($0) }
                Spacer(minLength: 0)
                Button(Copy.Match.commit) { session.commit() }
                    .appButton(.primary)
                    .disabled(session.preview == nil)
            } else {
                // S-10 · دور غيرك، وعرض اللوح بعد كل دور
                statusLine(otherStatus(view), palette)
                if kind != "display", let deadline = view.phase.deadline {
                    TimerView(deadline: deadline, total: kind == "choosing" ? MatchRules.chooseMs : MatchRules.answerMs, now: now)
                }
                SplitPicker(options: [(Tab.board, Copy.Match.boardTab), (Tab.question, Copy.Match.questionTab)], selection: $tab)
                if tab == .board || kind == "display" {
                    BoardView(view: view)
                } else if let round = view.round {
                    ScrollView {
                        VStack(spacing: Space.s(3)) {
                            QuestionCard(question: round.question)
                            AnswerOptions(question: round.question, selected: round.answer, enabled: false) { _ in }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, Space.s(3))
        .padding(.vertical, Space.s(2))
    }

    private func header(_ view: MatchView, _ palette: Palette) -> some View {
        HStack(alignment: .top, spacing: Space.s(1)) {
            ForEach(view.order.compactMap { view.seat($0) }) { seat in
                SeatBadge(seat: seat, active: view.round?.seatNo == seat.seatNo && view.phase.kind != "countdown")
            }
            Button { confirmExit = true } label: {
                Image("icon-x").resizable().frame(width: IconSize.small, height: IconSize.small)
                    .foregroundStyle(palette.textMuted)
                    .frame(width: Touch.min, height: Touch.min)
            }
            .accessibilityLabel(Copy.Match.exit)
        }
    }

    private func statusLine(_ text: String, _ palette: Palette) -> some View {
        Text(text).font(.app(.body, .bold)).foregroundStyle(palette.text)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func otherStatus(_ view: MatchView) -> String {
        guard let round = view.round else { return "" }
        let name = view.seat(round.seatNo).map { "\u{2068}\($0.displayName)\u{2069}" } ?? ""
        let me = round.seatNo == TrainingSession.mySeat
        if view.phase.kind == "display" {
            if round.choiceDropped == true { return me ? Copy.Match.droppedMine : Copy.Match.dropped(name) }
            switch round.result {
            case "correct": return me ? Copy.Match.committedMine : Copy.Match.correct(name)
            case "wrong": return me ? Copy.Match.wrongMine : Copy.Match.wrong(name)
            default: return me ? Copy.Match.timeoutMine : Copy.Match.timeout(name)
            }
        }
        return view.phase.kind == "choosing" ? Copy.Match.choosing(name) : Copy.Match.turnOf(name)
    }
}

/// مهلتا الإجابة والاختيار (R-19) — للعرض وحده؛ الحاكم المحرّك (types.ts: TIMES).
enum MatchRules {
    static let answerMs: Double = 15_000
    static let chooseMs: Double = 20_000
}

/// «استعدّ ٣-٢-١» (05-ui §٦): بمقاس ثابت لا يكبر بإعداد الخط، ويسكن حجمه عند تقليل الحركة.
struct CountdownView: View {
    let until: Double
    let now: Double
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let palette = Palette.of(scheme)
        let n = max(1, Int(((until - now) / 1000).rounded(.up)))
        VStack(spacing: Space.s(2)) {
            Spacer()
            Text(Copy.Match.ready).font(.app(.h1, .bold)).foregroundStyle(palette.textMuted)
            Text(verbatim: String(n))
                .font(.custom(Tokens.Font.familyAr, fixedSize: TokenValue.px(Tokens.Countdown.sizeMobile) * 0.6).weight(.bold))
                .foregroundStyle(palette.text)
                .monospacedDigit()
                .id(n)
                .transition(reduceMotion ? .identity : .scale(scale: TokenValue.number(Tokens.Countdown.enterScale)).combined(with: .opacity))
            Spacer()
        }
        .animation(reduceMotion ? nil : .easeOut(duration: TokenValue.seconds(Tokens.Motion.reveal)), value: n)
        .frame(maxWidth: .infinity)
        .accessibilityElement()
        .accessibilityLabel("\(Copy.Match.ready) \(n)")
    }
}
