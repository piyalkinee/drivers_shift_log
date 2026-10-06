import Foundation

struct PendingTrip: Codable, Equatable {
    let trip: Trip
    let serverURL: String
}

// One persistent outbox slot. A retry always uses the original ID, payload and server.
@MainActor
final class TripSubmission: ObservableObject {
    @Published private(set) var pending: PendingTrip?
    @Published private(set) var saving = false
    @Published private(set) var error: String?
    private let defaults: UserDefaults
    private let key = "pendingTrip.v2"
    private let send: (Trip, String) async throws -> Void
    private var recoveryFailed = false

    init(defaults: UserDefaults = .standard,
         send: @escaping (Trip, String) async throws -> Void = { trip, server in
             try await API(baseURL: server).add(trip)
         }) {
        self.defaults = defaults
        self.send = send
        if let data = defaults.data(forKey: key) {
            do { pending = try JSONDecoder().decode(PendingTrip.self, from: data) }
            catch { recoveryFailed = true; self.error = "Не удалось прочитать сохранённую отправку. Данные сохранены; повторная отправка заблокирована." }
        }
    }

    func submit(_ trip: Trip, serverURL: String) async -> Bool {
        guard !saving, !recoveryFailed else { return false }
        guard pending != nil || AppConfiguration.isValid(serverURL) else {
            error = "Укажите корректный адрес сервера в настройках подключения."
            return false
        }
        saving = true
        error = nil
        defer { saving = false }
        do {
            let request = pending ?? PendingTrip(trip: trip, serverURL: serverURL)
            let data = try JSONEncoder().encode(request)
            defaults.set(data, forKey: key)
            pending = request
            try await send(request.trip, request.serverURL)
            defaults.removeObject(forKey: key)
            pending = nil
            return true
        } catch {
            // Definitive validation rejection means nothing was committed. Allow editing.
            if let apiError = error as? APIError, [400, 422].contains(apiError.statusCode) {
                defaults.removeObject(forKey: key)
                pending = nil
            }
            self.error = error.localizedDescription
            return false
        }
    }
}
