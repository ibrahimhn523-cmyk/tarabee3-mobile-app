import SwiftUI

@main
struct Tarabee3App: App {
    @State private var store = ProfileStore(backend: FirebaseBackend.configured())

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
        }
    }
}

/// الجذر: الاتجاه من اليمين ولو كانت لغة الجهاز غير العربية (القاعدة ٨)، والأرقام غربية (R-70)،
/// والمظهر من الإعدادات (R-69)، وسقف حجم الخط (type-scale.max).
struct RootView: View {
    let store: ProfileStore
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .system

    var body: some View {
        content
            .appEnvironment(appearance)
            .task { await store.start() }
    }

    @ViewBuilder private var content: some View {
        switch store.phase {
        case .ready:
            if let player = store.player { HomeView(store: store, player: player) } else { LoadingView() }
        case .firstOpen:
            FirstOpenView(store: store)
        case .loading:
            LoadingView()
        case .notConfigured:
            MessageView(text: Copy.Status.notConfigured)
        case .failed:
            MessageView(text: Copy.Status.noInternet) { Task { await store.start() } }
        }
    }
}

private struct LoadingView: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(spacing: Space.s(3)) {
            Image("Logo-vertical").resizable().scaledToFit().frame(height: 120).accessibilityLabel("ترابيع")
            ProgressView().tint(Palette.of(scheme).text)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
        .accessibilityLabel(Copy.Status.loading)
    }
}

private struct MessageView: View {
    let text: String
    var retry: (() -> Void)?
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(spacing: Space.s(4)) {
            Image("Logo-vertical").resizable().scaledToFit().frame(height: 120).accessibilityLabel("ترابيع")
            StatusBanner(kind: .error, text: text)
            if let retry {
                Button(Copy.Status.retry, action: retry).appButton(.primary)
            }
            Text(verbatim: BuildInfo.text).font(.app(.caption)).foregroundStyle(Palette.of(scheme).textMuted)
        }
        .padding(Space.s(3))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
    }
}

extension View {
    /// بيئة كل شاشة ولوحة (اللوحات لا ترث كل البيئة دائماً): الاتجاه، والأرقام، والمظهر، وسقف الخط.
    func appEnvironment(_ appearance: Appearance) -> some View {
        environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ar@numbers=latn"))
            .preferredColorScheme(appearance.scheme)
            .dynamicTypeSize(...TypeScaleCap.max)
    }
}

/// الإصدار ورقم البناء، ليتحقّق المالك أن جواله على آخر بناء (M-01).
enum BuildInfo {
    static var text: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(version) (\(build))"
    }
}
