import Foundation

struct Trip: Codable, Identifiable, Equatable {
    var id: String
    var start: Date
    var end: Date
    var amount: Int
    var payment: String
    var commission: Int
}
struct Summary: Codable {
    let count: Int
    let revenue: Int
    let commission: Int
    let net: Int
    let cash: Int
    let card: Int
}
struct Day: Codable {
    let date: String
    let timezone: String
    let summary: Summary
    let trips: [Trip]
}
enum LocalDay {
    static let zone = TimeZone(secondsFromGMT: 5 * 3600)!
    static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = zone
        return value
    }
    static func key(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = zone
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
    static func label(_ date: Date, format: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = zone
        f.dateFormat = format
        return f.string(from: date)
    }
}
func money(_ value: Int) -> String {
    value.formatted(.number.grouping(.automatic).locale(Locale(identifier: "ru_RU"))) + " ₸"
}
