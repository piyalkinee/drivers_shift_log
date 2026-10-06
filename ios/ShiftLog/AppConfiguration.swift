import Foundation

enum AppConfiguration {
    static var defaultServerURL: String {
        Bundle.main.object(forInfoDictionaryKey: "ShiftLogAPIBaseURL") as? String ?? ""
    }
    static var initialDate: Date {
        initialDate(from: Bundle.main.object(forInfoDictionaryKey: "ShiftLogInitialDate") as? String)
    }
    static func initialDate(from value: String?, now: Date = Date()) -> Date {
        guard let value else { return now }
        let formatter = DateFormatter()
        formatter.calendar = LocalDay.calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = LocalDay.zone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: value), LocalDay.key(date) == value else { return now }
        return date
    }
    static func normalized(_ text: String) -> String {
        var text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasSuffix("/") { text.removeLast() }
        return text
    }
    static func isValid(_ text: String) -> Bool {
        guard let url = URL(string: normalized(text)) else { return false }
        return ["http", "https"].contains(url.scheme) && url.host != nil
            && url.user == nil && url.password == nil && url.query == nil
            && url.fragment == nil && url.path.isEmpty
    }
}
