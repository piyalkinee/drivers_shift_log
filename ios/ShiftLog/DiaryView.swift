import SwiftUI

struct DiaryView: View {
    @AppStorage("serverURL") private var serverURL = AppConfiguration.defaultServerURL
    @State private var date = Date()
    @StateObject private var model = DiaryModel()
    private var day: Day? { model.day }
    private var loading: Bool { model.loading }
    private var error: String? { model.error }
    @State private var adding = false
    @State private var settings = false
    @State private var choosingDate = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    datePicker
                    if loading {
                        ProgressView("Загружаем смену…").frame(maxWidth: .infinity).padding(50)
                    } else if let error {
                        ContentUnavailableView {
                            Label(serverURL.isEmpty ? "Подключите сервер" : "Не удалось загрузить смену", systemImage: "wifi.exclamationmark")
                        } description: { Text(error) } actions: {
                            Button("Повторить") { Task { await reload() } }
                            Button("Настройки сервера") { settings = true }
                        }
                    } else if let day {
                        earnings(day.summary)
                        payments(day.summary)
                        HStack(alignment: .firstTextBaseline) {
                            Text("Поездки").font(.title2.bold())
                            Text("\(day.summary.count)").font(.subheadline.bold()).foregroundStyle(Theme.muted)
                            Spacer()
                            Text("ПО ВРЕМЕНИ").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Theme.muted)
                        }
                        if day.trips.isEmpty {
                            ContentUnavailableView("Пока нет поездок", systemImage: "steeringwheel", description: Text("Добавьте первую поездку этой смены."))
                        } else {
                            VStack(spacing: 0) {
                                ForEach(day.trips) { trip in
                                    tripRow(trip)
                                    if trip.id != day.trips.last?.id { Divider().padding(.leading, 66) }
                                }
                            }.background(Theme.panel, in: RoundedRectangle(cornerRadius: 24))
                        }
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                            Text("День по началу поездки · Алматы, UTC+5")
                        }.font(.caption2).foregroundStyle(Theme.muted).frame(maxWidth: .infinity)
                    }
                }.padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 24)
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                Button { adding = true } label: {
                    Label("Добавить поездку", systemImage: "plus").font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                }.accessibilityIdentifier("addTrip").buttonStyle(.plain).foregroundStyle(Theme.background)
                    .background(Theme.lime, in: RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 8)
                    .background(Theme.background)
            }
            .task(id: "\(LocalDay.key(date))|\(serverURL)") { await reload() }
            .refreshable { await reload() }
            .sheet(isPresented: $adding) {
                AddTripView(date: date, api: API(baseURL: serverURL)) { savedDate in
                    date = savedDate
                    Task { await reload() }
                }
            }
            .sheet(isPresented: $settings) { SettingsView(serverURL: $serverURL) }
            .sheet(isPresented: $choosingDate) {
                NavigationStack {
                    DatePicker("День смены", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.graphical).padding()
                        .navigationTitle("Выберите день")
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { choosingDate = false } } }
                }.presentationDetents([.medium, .large])
            }
        }
    }
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Circle().fill(Theme.lime).frame(width: 6, height: 6)
                    Text("ДНЕВНИК ВОДИТЕЛЯ").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(2).foregroundStyle(Theme.muted)
                }
                Text("Смена").font(.system(size: 38, weight: .bold, design: .rounded))
            }
            Spacer()
            Button { settings = true } label: {
                Image(systemName: "slider.horizontal.3").font(.title3).foregroundStyle(.white)
                    .frame(width: 48, height: 48).background(Theme.panel, in: Circle())
            }.accessibilityLabel("Настройки сервера")
        }
    }
    private var datePicker: some View {
        HStack {
            Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 42, height: 48) }.accessibilityLabel("Предыдущий день")
            Spacer()
            Button { choosingDate = true } label: {
                VStack(spacing: 4) {
                    Text(LocalDay.label(date, format: "d MMMM yyyy")).font(.headline)
                    Text(LocalDay.label(date, format: "EEEE").capitalized).font(.caption).foregroundStyle(Theme.muted)
                }
            }
            Spacer()
            Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 42, height: 48) }.accessibilityLabel("Следующий день")
        }.foregroundStyle(.white).padding(7).background(Theme.panel, in: RoundedRectangle(cornerRadius: 18))
    }
    private func earnings(_ s: Summary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("На руки", systemImage: "arrow.down.left").font(.subheadline.weight(.medium))
                Spacer()
                Text("ЗА ДЕНЬ").font(.system(size: 10, weight: .bold, design: .monospaced)).padding(.horizontal, 10).padding(.vertical, 6).background(.black.opacity(0.08), in: Capsule())
            }
            Text(money(s.net)).accessibilityIdentifier("dayNet").font(.system(size: 42, weight: .bold, design: .rounded)).minimumScaleFactor(0.4).lineLimit(1)
            Rectangle().fill(.black.opacity(0.14)).frame(height: 1)
            HStack {
                metric("Выручка", money(s.revenue))
                Spacer()
                metric("Комиссия", money(s.commission))
            }
        }.foregroundStyle(Theme.background).padding(22).background(Theme.lime, in: RoundedRectangle(cornerRadius: 28))
    }
    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(.caption).opacity(0.65)
            Text(value).font(.system(.title3, design: .rounded, weight: .bold)).lineLimit(1).minimumScaleFactor(0.6)
        }
    }
    private func payments(_ s: Summary) -> some View {
        HStack(spacing: 12) {
            payment("Наличные", amount: s.cash, icon: "banknote", color: Theme.lime)
            payment("Карта", amount: s.card, icon: "creditcard", color: Color(red: 0.61, green: 0.73, blue: 1))
        }
    }
    private func payment(_ label: String, amount: Int, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: icon).foregroundStyle(color); Text(label).font(.caption).foregroundStyle(Theme.muted) }
            Text(money(amount)).font(.system(.title3, design: .rounded, weight: .bold)).lineLimit(1).minimumScaleFactor(0.6)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18).background(Theme.panel, in: RoundedRectangle(cornerRadius: 20))
    }
    private func tripRow(_ t: Trip) -> some View {
        HStack(spacing: 13) {
            Image(systemName: t.payment == "cash" ? "banknote" : "creditcard")
                .foregroundStyle(t.payment == "cash" ? Theme.lime : .white)
                .frame(width: 38, height: 42).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 7) {
                Text("\(LocalDay.label(t.start, format: "HH:mm")) — \(LocalDay.label(t.end, format: "HH:mm"))").font(.subheadline.bold())
                Text("\(Int(t.end.timeIntervalSince(t.start) / 60)) мин · \(t.payment == "cash" ? "Наличные" : "Карта")").font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 7) {
                Text(money(t.amount)).font(.subheadline.bold())
                Text("−\(money(t.commission)) комиссия").font(.system(size: 10)).foregroundStyle(Theme.muted)
            }
        }.padding(16)
    }
    private func move(_ value: Int) { date = LocalDay.calendar.date(byAdding: .day, value: value, to: date)! }
    @MainActor private func reload() async {
        await model.load(date: date, fetch: API(baseURL: serverURL).day)
    }
}

struct SettingsView: View {
    @Binding var serverURL: String
    @State private var draft = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Адрес API") {
                    TextField("http://localhost:8080", text: $draft).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                }
                Section {
                    Text("В симуляторе используйте localhost. На iPhone укажите адрес Mac в той же Wi-Fi сети, например http://192.168.1.10:8080.")
                }.foregroundStyle(.secondary)
            }.navigationTitle("Подключение")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { serverURL = AppConfiguration.normalized(draft); dismiss() }.disabled(!AppConfiguration.isValid(draft)) } }
                .onAppear { draft = serverURL }
        }
    }
}
