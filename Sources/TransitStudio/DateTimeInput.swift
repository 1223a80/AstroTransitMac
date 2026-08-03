import SwiftUI

struct DateTimeInput: View {
    @Binding var date: Date
    let timeZone: TimeZone
    var showsSeconds: Bool = false
    @State private var text = ""
    @FocusState private var isEditing: Bool

    init(date: Binding<Date>, timeZone: TimeZone = .current, showsSeconds: Bool = false) {
        _date = date
        self.timeZone = timeZone
        self.showsSeconds = showsSeconds
    }

    static func makeFormatter(timeZone: TimeZone, showsSeconds: Bool = false) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = showsSeconds ? "yyyy-MM-dd HH:mm:ss" : "yyyy-MM-dd HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        return formatter
    }

    private var formatter: DateFormatter {
        Self.makeFormatter(timeZone: timeZone, showsSeconds: showsSeconds)
    }

    var body: some View {
        HStack(spacing: TS.Spacing.md) {
            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .environment(\.timeZone, timeZone)
                .onChange(of: date) { newValue in
                    if !isEditing {
                        text = formatter.string(from: newValue)
                    }
                }

            TextField(showsSeconds ? "yyyy-MM-dd HH:mm:ss" : "yyyy-MM-dd HH:mm", text: $text)
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
        .onChange(of: timeZone.secondsFromGMT(for: date)) { _ in
            if !isEditing {
                text = formatter.string(from: date)
            }
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
