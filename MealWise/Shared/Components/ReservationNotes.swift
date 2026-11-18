import SwiftUI

struct ReservationNotes: View {
    let notes: [ReservationNote]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(notes) { note in
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(note.name)).font(.headline)
                    Text("Reserve \(QuantityFormatting.display(amount: note.quantity, unit: note.unit)) · Later meals: \(note.mealCount)")
                        .font(.subheadline)
                }
            }
            if !notes.isEmpty {
                Text("Follow package storage instructions.").font(.footnote)
                    .foregroundStyle(DesignTokens.textSecondary)
            }
        }
    }
}

#Preview { ReservationNotes(notes: []).padding() }
