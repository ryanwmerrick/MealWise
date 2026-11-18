import SwiftUI

struct ReservationNotes: View {
    let notes: [ReservationNote]
    var body: some View {
        ForEach(notes) { note in
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStringKey(note.name)).font(.headline)
                Text("Reserve \(QuantityFormatting.display(amount: note.quantity, unit: note.unit)) for the remaining planned meals.")
                Text("Later meals using this ingredient: \(note.mealCount)").font(.caption)
                Text("These amounts belong to other planned recipes. Follow package storage instructions when saving ingredients.").font(.footnote)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Color("NoteText"))
            .background(Color("NoteFill"), in: RoundedRectangle(cornerRadius: 18))
        }
    }
}

#Preview { ReservationNotes(notes: []).padding() }
