import SwiftUI

@main
struct ShiftLogApp: App {
    var body: some Scene {
        WindowGroup {
            DiaryView()
                .preferredColorScheme(.dark)
                .environment(\.locale, Locale(identifier: "ru_RU"))
                .environment(\.timeZone, LocalDay.zone)
                .tint(Theme.lime)
        }
    }
}
enum Theme {
    static let background = Color(red: 0.045, green: 0.065, blue: 0.08)
    static let panel = Color(red: 0.085, green: 0.11, blue: 0.13)
    static let lime = Color(red: 0.80, green: 0.96, blue: 0.36)
    static let muted = Color(red: 0.57, green: 0.64, blue: 0.68)
}
