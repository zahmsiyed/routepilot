import SwiftUI

@main
struct RoutePilotApp: App {
    @StateObject private var model = RoutePilotModel()

    private var testAppearance: ColorScheme? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-dark") { return .dark }
        #endif
        return nil
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .tint(AppTheme.tint)
                .accentColor(AppTheme.tint)
                .preferredColorScheme(testAppearance)
                .modifier(TestAccessibilitySize())
        }
    }
}

/// Keep controls readable in both appearances, including the setup sheet.
enum AppTheme {
    static let tint = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.48, green: 0.80, blue: 0.64, alpha: 1)
            : UIColor(red: 0.14, green: 0.39, blue: 0.29, alpha: 1)
    })
}

private struct TestAccessibilitySize: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-large-text") {
            content.dynamicTypeSize(.accessibility3)
        } else { content }
        #else
        content
        #endif
    }
}
