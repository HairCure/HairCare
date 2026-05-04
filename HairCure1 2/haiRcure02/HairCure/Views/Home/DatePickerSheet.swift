import SwiftUI

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    let accentColor: Color
    @Binding var isPresented: Bool

    private let range: PartialRangeThrough<Date> = ...Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    in: range,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(accentColor)
                .padding(.horizontal, 12)
                .padding(.top, 8)

                Spacer()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // Clamp to start of day so queries match
                        selectedDate = Calendar.current.startOfDay(for: selectedDate)
                        isPresented  = false
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(accentColor)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .foregroundStyle(.secondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
