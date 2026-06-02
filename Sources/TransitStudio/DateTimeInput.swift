import SwiftUI

struct DateTimeInput: View {
    @Binding var date: Date
    @State private var text = ""
    @FocusState private var isEditing: Bool

    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    var body: some View {
        HStack(spacing: 8) {
            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .onChange(of: date) { newValue in
                    if !isEditing {
                        text = formatter.string(from: newValue)
                    }
                }

            TextField("yyyy-MM-dd HH:mm", text: $text)
                .textFieldStyle(.roundedBorder)
                .monospacedDigit()
                .focused($isEditing)
                .onSubmit(commitText)
                .onChange(of: isEditing) { editing in
                    if !editing {
                        commitText()
                    }
                }
                .frame(minWidth: 155)
        }
        .onAppear {
            text = formatter.string(from: date)
        }
    }

    private func commitText() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let parsed = formatter.date(from: trimmed) {
            date = parsed
        } else {
            text = formatter.string(from: date)
        }
    }
}
