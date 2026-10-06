import Foundation

struct APIError: LocalizedError {
    let message: String
    var statusCode: Int? = nil
    var errorDescription: String? { message }
}
struct API {
    let baseURL: String
    var session: URLSession = .shared
    private func request(path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard let base = URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(base.scheme), base.host != nil, base.user == nil, base.password == nil,
              base.query == nil, base.fragment == nil, (base.path.isEmpty || base.path == "/"),
              let url = URL(string: path, relativeTo: base)?.absoluteURL else {
            throw APIError(message: "Проверьте адрес сервера в настройках")
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 15
        req.httpBody = body
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await session.data(for: req)
        guard let response = response as? HTTPURLResponse else { throw APIError(message: "Нет ответа сервера") }
        guard (200..<300).contains(response.statusCode) else {
            let error = try? JSONDecoder().decode([String: String].self, from: data)
            throw APIError(message: error?["error"] ?? "Ошибка сервера: \(response.statusCode)", statusCode: response.statusCode)
        }
        return data
    }
    func day(_ date: Date) async throws -> Day {
        let data = try await request(path: "/api/day?date=\(LocalDay.key(date))")
        return try Self.decodeDay(data)
    }
    static func decodeDay(_ data: Data) throws -> Day {
        try decoder().decode(Day.self, from: data)
    }
    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: text) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: text) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid RFC3339 date")
        }
        return decoder
    }
    func add(_ trip: Trip) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payload = try encoder.encode(trip)
        let data = try await request(path: "/api/trips", method: "POST", body: payload)
        struct Confirmation: Decodable { let trip: Trip; let created: Bool }
        let confirmation = try Self.decoder().decode(Confirmation.self, from: data)
        let sent = try Self.decoder().decode(Trip.self, from: payload)
        guard confirmation.trip == sent else {
            throw APIError(message: "Сервер подтвердил другую поездку. Отправка сохранена для повтора.")
        }
    }
}
