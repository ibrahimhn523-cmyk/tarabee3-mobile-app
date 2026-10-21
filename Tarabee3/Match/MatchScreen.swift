import SwiftUI

/// شاشات المباراة (S-09 إلى S-14) تملأ الشاشة بلا زرّ رجوع، والمحرّك ينقل بينها (05-ui §٨).
/// في التدريب يحكمها المحرّك على الجهاز؛ وأون لاين (M-06) يحكمها الكائن والشاشات نفسها.
struct MatchScreen: View {
    let session: any MatchSession
    var onPlayAgain: () -> Void
    var onExit: () -> Void

    @State private var tab = Tab.board
    @State private var confirmExit = false
    @State private var showCards = false
    @State private var choiceMode = ChoiceMode.square
    @Environment(\.colorScheme) private var scheme

    enum Tab: Hashable { case board, question }
    enum ChoiceMode: Hashable { case square, box }

    var body: some View {
        let palette = Palette.of(scheme)
        Group {
            if let view = session.view {
                if view.phase.kind == "ended" {
                    TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                        let online = session as? OnlineSession
                        ResultScreen(
                            view: view, session: session, onPlayAgain: onPlayAgain, onHome: onExit,
                            notice: view.phase.reason == "cancelled" ? Copy.Online.cancelled
                                : online?.endedWhileAway == true ? Copy.Online.endedBeforeReturn : nil,
                            rematch: online?.rematch, now: session.now,
                            onRematch: { online?.respondRematch($0) }
                        )
                    }
                } else {
                    TimelineView(.periodic(from: .now, by: 0.2)) { _ in
                        if let window = session.myBurnWindow, let until = view.phase.until {
                            // S-13 · نافذة الحرق تملأ الشاشة
                            BurnScreen(session: session, window: window, until: until)
                        } else {
                            playing(view, palette)
                        }
                    }
                }
            } else if let failure = session.failureText {
                VStack(spacing: Space.s(4)) {
                    StatusBanner(kind: .error, text: failure)
                    Button(Copy.Match.home, action: onExit).appButton(.secondary)
                }
                .padding(Space.s(3))
            } else {
                ProgressView().tint(palette.text)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
        .overlay {
            // غطاء إعادة الاتصال (05-ui §٦): يحجب المباراة حتى يعود
            if let online = session as? OnlineSession, online.reconnecting {
                ZStack {
                    palette.ground.ignoresSafeArea()
                    VStack(spacing: Space.s(3)) {
                        ProgressView().tint(palette.text)
                        Text(Copy.Online.reconnecting).font(.app(.body, .bold)).foregroundStyle(palette.text)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .sheet(isPresented: $showCards) {
            CardsSheet(session: session) { showCards = false }
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $confirmExit) {
            VStack(alignment: .leading, spacing: Space.s(4)) {
                Text(session.repliesEnabled ? Copy.Online.withdrawTitle : Copy.Match.exitTitle).font(.app(.h2, .bold)).foregroundStyle(palette.text)
                Text(session.repliesEnabled ? Copy.Online.withdrawConfirm : Copy.Match.exitConfirm).font(.app(.body)).foregroundStyle(palette.text)
                Spacer(minLength: 0)
                // أون لاين: الانسحاب نهائي ويحلّ آلي مكانه (R-43)
                Button(session.repliesEnabled ? Copy.Online.withdraw : Copy.Match.exit) {
                    confirmExit = false
                    (session as? OnlineSession)?.withdraw()
                    onExit()
                }.appButton(.danger)
                Button(Copy.Settings.cancel) { confirmExit = false }.appButton(.plain).frame(maxWidth: .infinity)
            }
            .padding(Space.s(4))
            .appBackground()
            .presentationDetents([.medium])
        }
        .onChange(of: session.view?.round?.id) { choiceMode = .square }
        .onChange(of: session.view?.round?.boardCard) { if session.view?.round?.boardCard != nil { choiceMode = .square } }
    }

    @ViewBuilder
    private func playing(_ view: MatchView, _ palette: Palette) -> some View {
        let now = session.now
        let kind = view.phase.kind
        VStack(spacing: Space.s(3)) {
            header(view, palette)
            if let notice = notice(view) {
                StatusBanner(kind: .info, text: notice)
            }

            if kind == "countdown" {
                CountdownView(until: view.phase.until ?? now, now: now)
            } else if kind == "paused" {
                // انقطع البشر كلهم: بلا سؤال ولا مؤقّت (R-71)
                statusLine(Copy.Online.paused, palette)
                BoardView(view: view)
                Spacer(minLength: 0)
            } else if session.targeting != nil {
                targetingView(view, palette)
            } else if kind == "answering" && session.isMyTurn, let round = view.round {
                // S-09 · دورك
                statusLine(round.anyAnswer == true ? Copy.Cards.anyActive : Copy.Match.yourTurn, palette)
                TimerView(deadline: round.deadline, total: view.times.answer, now: now)
                ScrollView {
                    VStack(spacing: Space.s(3)) {
                        QuestionCard(question: round.question)
                        AnswerOptions(question: round.question, selected: session.sentAnswer,
                                      enabled: session.sentAnswer == nil) { session.answer($0) }
                    }
                }
                CardsButton(session: session, showCards: $showCards)
            } else if kind == "group", let round = view.round {
                // S-12 · جولة جماعية: من أجاب يُعلَّم بلا كشف صوابه (R-26)
                statusLine(round.myAnswer == nil ? Copy.Group.title : Copy.Group.waiting, palette)
                Text(Copy.Group.line).font(.app(.small)).foregroundStyle(palette.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TimerView(deadline: round.deadline, total: view.times.answer, now: now)
                ScrollView {
                    VStack(spacing: Space.s(3)) {
                        QuestionCard(question: round.question)
                        AnswerOptions(question: round.question, selected: round.myAnswer,
                                      enabled: session.canAnswerGroup) { session.answer($0) }
                    }
                }
            } else if session.isChooser, let deadline = view.phase.deadline {
                // S-11 · اختيار الأحقية: مربع أم صندوق
                chooseView(view, deadline: deadline, palette)
            } else if kind == "burn" {
                statusLine(burnWaiting(view), palette)
                BoardView(view: view)
                Spacer(minLength: 0)
            } else {
                // S-10 · دور غيرك، وعرض اللوح بعد كل دور
                statusLine(otherStatus(view), palette)
                if session.repliesEnabled { RepliesRow(session: session) }
                if kind != "display", let deadline = view.phase.deadline {
                    TimerView(deadline: deadline, total: kind == "choosing" ? view.times.choose : view.times.answer, now: now)
                }
                SplitPicker(options: [(Tab.board, Copy.Match.boardTab), (Tab.question, Copy.Match.questionTab)], selection: $tab)
                if tab == .board || kind == "display" {
                    BoardView(view: view)
                } else if let round = view.round {
                    ScrollView {
                        VStack(spacing: Space.s(3)) {
                            QuestionCard(question: round.question)
                            AnswerOptions(question: round.question, selected: round.answer ?? round.myAnswer, enabled: false) { _ in }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, Space.s(3))
        .padding(.vertical, Space.s(2))
    }

    /// S-11: خياران متجاوران، والصندوق معطّل إن نفدت والعدد ظاهر (05-ui §٦). وبعد كرت لوح يبقى المربع وحده.
    @ViewBuilder
    private func chooseView(_ view: MatchView, deadline: Double, _ palette: Palette) -> some View {
        let boxes = session.me?.boxesLeft ?? 0
        let boardCard = view.round?.boardCard
        let note = boardCard == .doubleCross ? Copy.Cards.doubleActive
            : boardCard == .placeAnywhere ? Copy.Cards.anywhereActive : Copy.Match.chooseSquare
        statusLine(choiceMode == .box ? Copy.Choice.openBox : note, palette)
        TimerView(deadline: deadline, total: view.times.choose, now: session.now)
        SplitPicker(options: [(ChoiceMode.square, Copy.Choice.square), (ChoiceMode.box, Copy.Choice.box(boxes))], selection: $choiceMode)
        if choiceMode == .box {
            Spacer(minLength: 0)
            Image("icon-package").resizable().frame(width: 64, height: 64).foregroundStyle(palette.text)
                .accessibilityHidden(true)
            if !session.canOpenBox {
                Text(boxes == 0 ? Copy.Choice.boxesGone : Copy.Choice.boxAfterCard).font(.app(.small)).foregroundStyle(palette.textMuted)
            }
            Spacer(minLength: 0)
            Button(Copy.Choice.openBox) { session.openBox() }.appButton(.primary).disabled(!session.canOpenBox)
        } else {
            BoardView(view: view, preview: session.preview, previewCells: session.previewCells,
                      previewSeat: session.mySeat) { session.select($0) }
            Spacer(minLength: 0)
            HStack(spacing: Space.s(2)) {
                CardsButton(session: session, showCards: $showCards)
                Button(Copy.Match.commit) { session.commit() }.appButton(.primary).disabled(!session.canCommit)
            }
        }
    }

    /// استهداف التفريغ أو التحصين: اللوح، ثم «اعتمد» أو «إلغاء». والمؤقّت يعمل.
    @ViewBuilder
    private func targetingView(_ view: MatchView, _ palette: Palette) -> some View {
        statusLine(isClearTargeting ? Copy.Cards.clearTarget : Copy.Cards.fortifyTarget, palette)
        if let deadline = view.phase.deadline {
            TimerView(deadline: deadline, total: view.times.answer, now: session.now)
        }
        BoardView(view: view, targetCells: session.targetCells) { session.select($0) }
        Spacer(minLength: 0)
        HStack(spacing: Space.s(2)) {
            Button(Copy.Cards.cancel) { session.cancelTarget() }.appButton(.secondary)
            Button(Copy.Cards.confirm) { session.confirmTarget() }.appButton(.primary).disabled(!session.targetReady)
        }
    }

    private var isClearTargeting: Bool {
        if case .clear = session.targeting { return true }
        return false
    }

    private func header(_ view: MatchView, _ palette: Palette) -> some View {
        let answered = Set(view.round?.answeredSeats ?? [])
        let activeSeat = view.phase.kind == "choosing" ? view.round?.chooser : view.round?.seatNo
        return HStack(alignment: .top, spacing: Space.s(1)) {
            ForEach(view.order.compactMap { view.seat($0) }) { seat in
                // S-12: «الشارات صفّاً أعلاها بلا كروت» (05-ui §٦)
                SeatBadge(seat: seat, active: activeSeat == seat.seatNo && view.phase.kind != "countdown",
                          answered: view.phase.kind == "group" && answered.contains(seat.seatNo),
                          showCards: view.phase.kind != "group")
                    .reportOnLongPress(seat, session: session)
                    .overlay(alignment: .top) {
                        // الرد الجاهز فوق شارة مرسله ثانيتين (05-ui §٦)
                        if let bubble = session.replies.last(where: { $0.seat == seat.seatNo && $0.until > session.now }) {
                            ReplyChip(text: Copy.Online.reply(bubble.reply)).offset(y: -Space.s(2))
                        }
                    }
            }
            Button { confirmExit = true } label: {
                Image("icon-x").resizable().frame(width: IconSize.small, height: IconSize.small)
                    .foregroundStyle(palette.textMuted)
                    .frame(width: Touch.min, height: Touch.min)
            }
            .accessibilityLabel(Copy.Match.exit)
        }
    }

    /// تنبيه أعلى المباراة: اكتمال العدد بآليين في أولها، أو إجابة ثانية مرفوضة (05-ui §١٠).
    private func notice(_ view: MatchView) -> String? {
        if let online = session as? OnlineSession, online.reconnectedUntil > session.now { return Copy.Online.reconnected }
        if let online = session as? OnlineSession, online.reportedUntil > session.now { return Copy.Online.reported }
        if session.lastRejection == "already_answered" { return Copy.Online.secondAnswer }
        if let online = session as? OnlineSession, online.filledWithBots, view.cycle <= 1, view.round?.id ?? 0 <= 1 { return Copy.Online.filledWithBots }
        return nil
    }

    private func statusLine(_ text: String, _ palette: Palette) -> some View {
        Text(text).font(.app(.body, .bold)).foregroundStyle(palette.text)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func name(_ view: MatchView, _ seat: Int?) -> String {
        seat.flatMap { view.seat($0) }.map { "\u{2068}\($0.displayName)\u{2069}" } ?? ""
    }

    private func burnWaiting(_ view: MatchView) -> String {
        let names = (view.phase.windows ?? []).filter { $0.decided == nil }.map { name(view, $0.seatNo) }
        return Copy.Burn.waiting(names.joined(separator: "، "))
    }

    private func otherStatus(_ view: MatchView) -> String {
        guard let round = view.round else { return "" }
        let kind = view.phase.kind
        // الصندوق: صاحبه يرى كرته، والباقون يرون أنه فتح صندوقاً (الكرت معلن على شارته)
        if kind == "display", round.choice == "box", let card = round.boxCard, let chooser = round.chooser {
            return chooser == session.mySeat ? Copy.Choice.gotCard(Copy.Cards.name(card.type)) : Copy.Choice.opened(name(view, chooser))
        }
        if round.isGroup {
            switch kind {
            case "display":
                if round.result == "noWinner" { return Copy.Group.noWinner }
                if round.choiceDropped == true {
                    return round.winnerSeat == session.mySeat ? Copy.Match.droppedMine : Copy.Match.dropped(name(view, round.winnerSeat))
                }
                return Copy.Group.winner(name(view, round.winnerSeat))
            case "choosing": return Copy.Match.choosing(name(view, round.chooser))
            default: return Copy.Group.title
            }
        }
        let who = name(view, round.seatNo)
        let me = round.seatNo == session.mySeat
        if kind == "display" {
            if round.choiceDropped == true { return me ? Copy.Match.droppedMine : Copy.Match.dropped(who) }
            switch round.result {
            case "correct": return me ? Copy.Match.committedMine : Copy.Match.correct(who)
            case "wrong": return me ? Copy.Match.wrongMine : Copy.Match.wrong(who)
            default: return me ? Copy.Match.timeoutMine : Copy.Match.timeout(who)
            }
        }
        return kind == "choosing" ? Copy.Match.choosing(who) : Copy.Match.turnOf(who)
    }
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
