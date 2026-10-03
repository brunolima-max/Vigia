import SwiftUI

enum Theme {
    static let olive = Color(red: 0.24, green: 0.29, blue: 0.16)
    static let gold  = Color(red: 0.79, green: 0.64, blue: 0.15)
}

struct Verse { let text: String; let ref: String }

// Texto da Almeida Corrigida Fiel (ACF), escrito de memória:
// confira cada versículo na sua Bíblia antes de usar como definitivo.
enum Verses {
    static let all: [Verse] = [
        Verse(text: "Sofre, pois, as aflições, como bom soldado de Jesus Cristo.", ref: "2 Timóteo 2:3"),
        Verse(text: "Revesti-vos de toda a armadura de Deus, para que possais estar firmes contra as astutas ciladas do diabo.", ref: "Efésios 6:11"),
        Verse(text: "Novas são cada manhã; grande é a tua fidelidade.", ref: "Lamentações 3:23"),
        Verse(text: "Ó Senhor, pela manhã ouvirás a minha voz; pela manhã me apresentarei a ti, e vigiarei.", ref: "Salmos 5:3"),
        Verse(text: "Lâmpada para os meus pés é a tua palavra, e luz para o meu caminho.", ref: "Salmos 119:105"),
        Verse(text: "Esforça-te, e tem bom ânimo; não pasmes, nem te espantes, porque o Senhor teu Deus é contigo, por onde quer que andares.", ref: "Josué 1:9"),
        Verse(text: "Deus é o nosso refúgio e fortaleza, socorro bem presente na angústia.", ref: "Salmos 46:1"),
        Verse(text: "Portanto, quer comais, quer bebais ou façais outra qualquer coisa, fazei tudo para glória de Deus.", ref: "1 Coríntios 10:31")
    ]
    static var today: Verse {
        let d = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return all[d % all.count]
    }
    static var random: Verse { all.randomElement()! }
}

struct Item: Identifiable, Codable {
    enum Kind: String, Codable { case alarm, reminder }
    var id = UUID()
    var kind: Kind
    var hour: Int
    var minute: Int
    var label: String
    var weekdays: Set<Int> = []      // 1 = domingo ... 7 = sábado (só alarmes)
    var repeatsDaily = true          // lembretes: diário (true) ou pontual (false)
    var at: Date? = nil              // data exata de itens que tocam uma vez só
    var sound: String? = nil         // nome do arquivo .caf em Library/Sounds
    var enabled = true

    var isOneShot: Bool { kind == .alarm ? weekdays.isEmpty : !repeatsDaily }

    mutating func arm() {
        guard isOneShot, kind == .alarm else { return }
        at = Calendar.current.nextDate(after: Date(),
                                       matching: DateComponents(hour: hour, minute: minute),
                                       matchingPolicy: .nextTime)
    }

    var subtitle: String {
        let names = ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"]
        var s: String
        if kind == .alarm {
            if weekdays.isEmpty { s = "Uma vez" }
            else if weekdays.count == 7 { s = "Todos os dias" }
            else if weekdays == [2, 3, 4, 5, 6] { s = "Segunda a sexta" }
            else { s = weekdays.sorted().map { names[$0 - 1] }.joined(separator: ", ") }
        } else if repeatsDaily {
            s = "Todo dia"
        } else if let at {
            let f = DateFormatter(); f.dateFormat = "dd/MM"
            s = "Em " + f.string(from: at)
        } else { s = "Uma vez" }
        return s + " · " + (sound.map(soundDisplayName) ?? "Padrão do iPhone")
    }
}

func soundDisplayName(_ file: String) -> String {
    file.replacingOccurrences(of: ".caf", with: "").replacingOccurrences(of: "_", with: " ")
}
