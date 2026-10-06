import Foundation

@MainActor
final class DiaryModel: ObservableObject {
    @Published private(set) var day: Day?
    @Published private(set) var loading = false
    @Published private(set) var error: String?
    private var requestID = UUID()

    func load(date: Date, fetch: (Date) async throws -> Day) async {
        let id = UUID()
        requestID = id
        loading = true
        error = nil
        day = nil
        do {
            let result = try await fetch(date)
            guard requestID == id else { return }
            loading = false
            guard !Task.isCancelled else { return }
            day = result
        } catch {
            guard requestID == id else { return }
            loading = false
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }
}
