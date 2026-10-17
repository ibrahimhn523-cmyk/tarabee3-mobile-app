import SwiftUI

// M-01: الشعار ورقم البناء وحدهما — لإثبات أن البناء وصل الجوال.
struct ContentView: View {
    private let buildNumber =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"

    var body: some View {
        VStack(spacing: 24) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220)
                .accessibilityLabel("ترابيع")

            Text(verbatim: buildNumber)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
