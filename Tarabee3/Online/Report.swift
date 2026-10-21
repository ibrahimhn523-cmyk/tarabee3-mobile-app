import SwiftUI

/// البلاغ عن اسم (R-60، S-10، S-14): ضغطة طويلة على اسم بشريّ غيرك ← «إبلاغ عن الاسم» ← تأكيد.
/// يصل المالك في لوحة فايربيس، ولا يرى المُبلَّغ عنه شيئاً.
struct ReportOnLongPress: ViewModifier {
    let seat: SeatView
    let session: any MatchSession
    @State private var asking = false

    private var online: OnlineSession? { session as? OnlineSession }
    /// بشريّ غيري لم أبلّغ عنه: والمنسحب بشريّ وإن لعب الآلي مكانه.
    private var reportable: Bool {
        guard let online else { return false }
        return seat.seatNo != online.mySeat && (!seat.isBot || seat.withdrawn == true) && !online.reportedSeats.contains(seat.seatNo)
    }

    func body(content: Content) -> some View {
        content
            .onLongPressGesture { if reportable { asking = true } }
            .accessibilityAction(named: Copy.Online.reportAction) { if reportable { asking = true } }
            .confirmationDialog(Copy.Online.reportConfirm("\u{2068}\(seat.displayName)\u{2069}"), isPresented: $asking, titleVisibility: .visible) {
                Button(Copy.Online.reportAction, role: .destructive) { online?.report(seat: seat.seatNo) }
                Button(Copy.Settings.cancel, role: .cancel) {}
            }
    }
}

extension View {
    func reportOnLongPress(_ seat: SeatView, session: any MatchSession) -> some View {
        modifier(ReportOnLongPress(seat: seat, session: session))
    }
}
