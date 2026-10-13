import SwiftUI
import SwiftData

@main
struct DigiCashApp: App {
    @StateObject private var store = DataStore()
    @StateObject private var prefs = Prefs.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if prefs.onboardingDone {
                    RootView()
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(store)
            .environmentObject(prefs)
        }
    }
}
