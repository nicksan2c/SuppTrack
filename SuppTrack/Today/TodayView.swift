import SuppTrackCore
import SwiftData
import SwiftUI

/// Today: AM/PM switch, warnings, and a checkbox per item (approved mockup v2).
struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Item.createdAt) private var items: [Item]
    @Query private var logs: [DoseLog]
    @AppStorage("ageGroup") private var ageGroup = AgeGroup.adult19to50
    @State private var slot = TodayModel.defaultSlot(now: .now, calendar: .current)
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Time of day", selection: $slot) {
                        Text("AM").tag(Slot.am)
                        Text("PM").tag(Slot.pm)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("today-slot-picker")
                }

                if !warnings.isEmpty {
                    Section {
                        ForEach(warnings, id: \.self) { text in
                            Label(text, systemImage: "exclamationmark.triangle.fill")
                                .symbolRenderingMode(.multicolor)
                                .font(.subheadline)
                        }
                    }
                    .listRowBackground(Color.orange.opacity(0.15))
                    .accessibilityIdentifier("today-warnings")
                }

                Section {
                    ForEach(rows) { row in
                        TodayRowView(row: row) { toggle(row) }
                    }
                } footer: {
                    Text(disclaimerText)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("today-disclaimer")
                }
                .accessibilityIdentifier("today-list")
            }
            .overlay {
                if rows.isEmpty {
                    ContentUnavailableView("Nothing for the \(slot == .am ? "morning" : "evening")",
                                           systemImage: "checklist",
                                           description: Text("Add bottles from the Scan tab."))
                }
            }
            .navigationTitle("Today")
            .toolbar {
                Button("Settings", systemImage: "gearshape") { showSettings = true }
                    .accessibilityIdentifier("today-settings-button")
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
        .accessibilityIdentifier("today-screen")
    }

    private var rows: [TodayRow] {
        TodayModel.rows(items: items, logs: logs, slot: slot, now: .now, calendar: .current)
    }

    private var warnings: [String] {
        let active = items.filter { !$0.isHidden && $0.isActive }
        let overlap = OverlapCalculator.findings(active.map(\.snapshot), age: ageGroup)
            .filter(FindingText.showsOnToday)
            .map(FindingText.text)
        let rx = active.filter(\.isRx)
        let flags = SpacingRules.doctorFlags(
            rxNames: Dictionary(uniqueKeysWithValues: rx.map { ($0.id, $0.name) }),
            supplements: active.filter { !$0.isRx }.map(\.snapshot)
        ).map(\.text)
        return overlap + flags
    }

    private func toggle(_ row: TodayRow) {
        if row.isChecked {
            for log in logs where log.itemID == row.item.id && log.slot == slot
                && Calendar.current.isDateInToday(log.takenAt) {
                context.delete(log)
            }
        } else {
            context.insert(DoseLog(itemID: row.item.id, slot: slot))
        }
    }
}

struct TodayRowView: View {
    let row: TodayRow
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                Image(systemName: row.isChecked ? "checkmark.square.fill" : row.hint != nil ? "square.dashed" : "square")
                    .font(.title2)
                    .foregroundStyle(row.isChecked ? .green : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(row.item.name)
                            .strikethrough(row.isChecked)
                            .foregroundStyle(row.isChecked ? .secondary : .primary)
                        if row.item.isRx { RxTag() }
                    }
                    if !subtitle.isEmpty {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    if let hint = row.hint {
                        Label(HintText.text(hint), systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("today-row-\(row.item.id.uuidString)")
    }

    private var subtitle: String {
        [row.item.doseText, row.item.note ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

enum HintText {
    /// "after 10:30 AM · 4 hrs after levothyroxine" or "4 hrs after levothyroxine".
    static func text(_ hint: SpacingHint) -> String {
        let wait = hint.hours < 1 ? "\(Int(hint.hours * 60)) min" : "\(hint.hours.formatted()) hrs"
        let rest = "\(wait) after \(shortName(hint.byItemName))"
        guard let time = hint.notBefore else { return rest }
        return "after \(time.formatted(date: .omitted, time: .shortened)) · \(rest)"
    }

    /// "levothyroxine sodium 0.1 MG Oral Tablet" → "levothyroxine sodium".
    static func shortName(_ name: String) -> String {
        let words = name.split(separator: " ").prefix { !$0.contains(where: \.isNumber) }
        return words.isEmpty ? name : words.joined(separator: " ")
    }
}
