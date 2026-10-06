import Foundation

enum AppConfiguration {
    static var defaultServerURL: String {
        Bundle.main.object(forInfoDictionaryKey: "ShiftLogAPIBaseURL") as? String ?? ""
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
