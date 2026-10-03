import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    var body: some View {
        TabView {
            ItemList(kind: .alarm).tabItem { Label("Alarmes", systemImage: "alarm") }
            ItemList(kind: .reminder).tabItem { Label("Lembretes", systemImage: "checklist") }
            SoundsView().tabItem { Label("Toques", systemImage: "music.note") }
        }
    }
}

struct VerseCard: View {
    let v = Verses.today
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Soli Deo Gloria").font(.caption).foregroundStyle(.secondary)
            Text(v.text).font(.callout)
            Text(v.ref).font(.caption.bold()).foregroundStyle(Theme.gold)
        }
        .padding(.leading, 10)
        .overlay(alignment: .leading) { Rectangle().fill(Theme.gold).frame(width: 4) }
        .padding(.vertical, 4)
    }
}

struct ItemList: View {
    @EnvironmentObject var store: Store
    let kind: Item.Kind
    @State private var adding = false

    var rows: [Item] {
        store.items.filter { $0.kind == kind }.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section { VerseCard() }
                Section {
                    ForEach(rows) { ItemRow(item: $0) }
                        .onDelete { idx in store.remove(idx.map { rows[$0].id }) }
                    if rows.isEmpty { Text("Nada por aqui ainda.").foregroundStyle(.secondary) }
                }
            }
            .navigationTitle(kind == .alarm ? "Alarmes" : "Lembretes")
            .toolbar { Button { adding = true } label: { Image(systemName: "plus") } }
            .sheet(isPresented: $adding) { Editor(kind: kind) }
        }
    }
}

struct ItemRow: View {
    @EnvironmentObject var store: Store
    let item: Item
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%02d:%02d", item.hour, item.minute))
                    .font(.system(size: 38, weight: .bold, design: .rounded)).monospacedDigit()
                Text(item.label.isEmpty ? (item.kind == .alarm ? "Alarme" : "Lembrete") : item.label)
                Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
            }
            .opacity(item.enabled ? 1 : 0.4)
            Spacer()
            Toggle("", isOn: Binding(get: { item.enabled }, set: { store.setEnabled(item.id, $0) }))
                .labelsHidden()
        }
    }
}

struct Editor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    let kind: Item.Kind
    @State private var time = Date()
    @State private var label = ""
    @State private var days: Set<Int> = [2, 3, 4, 5, 6]
    @State private var daily = true
    @State private var day = Date()
    @State private var sound: String? = nil

    private var templates: [(String, Int, Int)] {
        kind == .alarm
            ? [("Toque de alvorada", 5, 30), ("Treino físico", 6, 0), ("Culto de domingo", 8, 30), ("Toque de silêncio", 22, 0)]
            : [("Oração da manhã", 6, 15), ("Leitura bíblica", 6, 30), ("Ordem do dia", 8, 0), ("Culto em família", 19, 30), ("Catecismo", 20, 0)]
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Horário", selection: $time, displayedComponents: .hourAndMinute)
                TextField("Nome", text: $label)
                Menu("Modelos") {
                    ForEach(templates, id: \.0) { t in
                        Button(t.0) {
                            label = t.0
                            time = Calendar.current.date(bySettingHour: t.1, minute: t.2, second: 0, of: Date()) ?? time
                        }
                    }
                }
                if kind == .alarm {
                    Section("Repetir em") {
                        HStack {
                            ForEach(1...7, id: \.self) { d in
                                Button(["D", "S", "T", "Q", "Q", "S", "S"][d - 1]) {
                                    if days.contains(d) { days.remove(d) } else { days.insert(d) }
                                }
                                .buttonStyle(.bordered)
                                .tint(days.contains(d) ? Theme.olive : .gray)
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                } else {
                    Picker("Frequência", selection: $daily) {
                        Text("Diário").tag(true); Text("Pontual").tag(false)
                    }.pickerStyle(.segmented)
                    if !daily { DatePicker("Data", selection: $day, displayedComponents: .date) }
                }
                Picker("Toque", selection: $sound) {
                    Text("Padrão do iPhone").tag(String?.none)
                    ForEach(store.sounds, id: \.self) { Text(soundDisplayName($0)).tag(String?.some($0)) }
                }
            }
            .navigationTitle(kind == .alarm ? "Novo alarme" : "Novo lembrete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Salvar") { save() } }
            }
        }
    }

    private func save() {
        let cal = Calendar.current
        let hm = cal.dateComponents([.hour, .minute], from: time)
        var item = Item(kind: kind, hour: hm.hour ?? 0, minute: hm.minute ?? 0,
                        label: label.trimmingCharacters(in: .whitespaces),
                        weekdays: kind == .alarm ? days : [],
                        repeatsDaily: kind == .alarm ? true : daily, sound: sound)
        if kind == .reminder && !daily {
            var dc = cal.dateComponents([.year, .month, .day], from: day)
            dc.hour = item.hour; dc.minute = item.minute
            item.at = cal.date(from: dc)
        }
        store.add(item)
        dismiss()
    }
}

struct SoundsView: View {
    @EnvironmentObject var store: Store
    @State private var importing = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Músicas do seu iPhone") {
                    ForEach(store.sounds, id: \.self) { f in
                        HStack {
                            Text(soundDisplayName(f))
                            Spacer()
                            Button(store.playing == f ? "Parar" : "Ouvir") { store.togglePreview(f) }
                                .buttonStyle(.bordered)
                            Button(role: .destructive) { store.deleteSound(f) } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless)
                        }
                    }
                    if store.sounds.isEmpty { Text("Nenhuma música ainda. Sem ela, toca o som padrão.").foregroundStyle(.secondary) }
                    Button("Adicionar música") { importing = true }
                }
                Section {
                    Text("O iOS limita toques de notificação a 30 segundos. O app corta a música em 29 s automaticamente.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Qual é o fim principal do homem?").font(.callout.bold())
                        Text("Glorificar a Deus e gozá-lo para sempre.").font(.callout)
                        Text("Catecismo Menor de Westminster, P. 1").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Toques")
            .fileImporter(isPresented: $importing, allowedContentTypes: [.audio], allowsMultipleSelection: true) { r in
                switch r {
                case .success(let urls):
                    for u in urls { do { try store.importSound(from: u) } catch { self.error = "Não consegui usar “\(u.lastPathComponent)”. Músicas protegidas (Apple Music) não funcionam." } }
                case .failure(let e): error = e.localizedDescription
                }
            }
            .alert("Atenção", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(error ?? "") }
        }
    }
}
