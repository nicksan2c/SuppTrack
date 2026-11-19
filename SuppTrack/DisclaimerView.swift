import SuppTrackCore
import SwiftUI

/// Exact wording required by the spec.
let disclaimerText = "Not medical advice. Consult a nutritionally informed physician."

struct DisclaimerView: View {
    @AppStorage("disclaimerAccepted") private var disclaimerAccepted = false
    @AppStorage("ageGroup") private var ageGroup = AgeGroup.adult19to50

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "pills.circle")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("SuppTrack")
                .font(.largeTitle.bold())
            Text(disclaimerText)
                .font(.title3)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("disclaimer-text")
            VStack(alignment: .leading) {
                Text("Your age group").font(.headline)
                AgeGroupPicker(selection: $ageGroup)
                Text("Used for upper limits (calcium is lower at 51+).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("disclaimer-age")
            Button("I understand") { disclaimerAccepted = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("disclaimer-accept")
        }
        .padding(32)
        .frame(maxWidth: 520)
        .accessibilityIdentifier("disclaimer-screen")
    }
}

struct AgeGroupPicker: View {
    @Binding var selection: AgeGroup

    var body: some View {
        Picker("Age group", selection: $selection) {
            Text("19–50").tag(AgeGroup.adult19to50)
            Text("51+").tag(AgeGroup.adult51plus)
        }
        .pickerStyle(.segmented)
    }
}
