import SwiftUI

@MainActor
struct AddTripView: View {
    let api: API
    let onSave: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var start: Date
    @State private var end: Date
    @State private var amount = ""
    @State private var commission = ""
    @State private var payment = "card"
    @FocusState private var editingMoney: Bool
    @StateObject private var submission: TripSubmission
    private var pending: Trip? { submission.pending?.trip }
    private var saving: Bool { submission.saving }
    private var error: String? { submission.error }
    init(date: Date, api: API, onSave: @escaping (Date) -> Void) {
        self.api = api; self.onSave = onSave
        let initial = LocalDay.calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date)!
        _start = State(initialValue: initial)
        _end = State(initialValue: initial.addingTimeInterval(20 * 60))
        let submission = TripSubmission()
        _submission = StateObject(wrappedValue: submission)
        if let trip = submission.pending?.trip {
            _start = State(initialValue: trip.start)
            _end = State(initialValue: trip.end)
            _amount = State(initialValue: String(trip.amount))
            _commission = State(initialValue: String(trip.commission))
            _payment = State(initialValue: trip.payment)
        }
    }
    private var valid: Bool {
        guard let amount = Int(amount), let commission = Int(commission) else { return false }
        return amount > 0 && amount <= 1_000_000_000 && commission >= 0 && commission <= amount && end > start
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Время · Алматы") {
                    DatePicker("Начало", selection: $start)
                    DatePicker("Окончание", selection: $end)
                }.disabled(pending != nil)
                Section {
                    HStack { Text("Сумма, ₸"); TextField("Сумма", text: $amount).accessibilityIdentifier("tripAmount").focused($editingMoney).multilineTextAlignment(.trailing).keyboardType(.numberPad) }
                    HStack { Text("Комиссия, ₸"); TextField("Комиссия", text: $commission).accessibilityIdentifier("tripCommission").focused($editingMoney).multilineTextAlignment(.trailing).keyboardType(.numberPad) }
                    Picker("Оплата", selection: $payment) { Text("Карта").tag("card"); Text("Наличные").tag("cash") }.pickerStyle(.segmented)
                } header: { Text("Оплата") } footer: { Text("Сумма больше нуля, комиссия от 0 до суммы. Окончание — позже начала. Для поездки через полночь выберите следующий день окончания.") }.disabled(pending != nil)
                if let amount = Int(amount), let commission = Int(commission), valid {
                    Section { HStack { Text("На руки"); Spacer(); Text(money(amount - commission)).bold().foregroundStyle(Theme.lime) } }
                }
                if let request = submission.pending {
                    Section { Text("Есть неподтверждённая поездка. Повтор уйдёт на исходный сервер: \(request.serverURL). Дубль не создастся.").font(.callout) }
                }
                if let error { Section { Text(error).foregroundStyle(.red); if pending != nil { Text("Повтор отправит ту же поездку с тем же ID. Поля сохранены до подтверждения сервера.").font(.caption) } } }
                Section {
                    Button { Task { await save() } } label: {
                        HStack { Spacer(); if saving { ProgressView() }; Text(pending == nil ? "Сохранить поездку" : "Повторить отправку"); Spacer() }
                    }.disabled(!valid || saving).accessibilityIdentifier("saveTrip")
                }
            }
            .navigationTitle("Новая поездка").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() }.disabled(saving) }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Готово") { editingMoney = false }.accessibilityIdentifier("dismissKeyboard") }
            }
            .interactiveDismissDisabled(saving)
        }
    }
    @MainActor private func save() async {
        guard valid, !saving else { return }
        let trip = pending ?? Trip(id: UUID().uuidString, start: start, end: end, amount: Int(amount)!, payment: payment, commission: Int(commission)!)
        if await submission.submit(trip, serverURL: api.baseURL) {
            onSave(trip.start)
            dismiss()
        }
    }
}
