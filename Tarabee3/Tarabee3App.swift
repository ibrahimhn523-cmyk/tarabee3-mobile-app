import SwiftUI

@main
struct Tarabee3App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // الاتجاه من اليمين ولو كانت لغة الجهاز غير العربية (القاعدة ٨)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
        }
    }
}
