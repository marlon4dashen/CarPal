import SwiftUI

struct EditVehicleView: View {
    @Binding private var draft: VehicleDraft
    private let engineModel: String
    private let canSubmit: Bool
    private let isSaving: Bool
    private let onSave: () -> Void
    private let onUnregister: () -> Void
    private let onCancel: () -> Void
    private let selectionPolicy = VehicleRegistrationSelectionPolicy()

    init(
        draft: Binding<VehicleDraft>,
        engineModel: String,
        canSubmit: Bool,
        isSaving: Bool = false,
        onSave: @escaping () -> Void,
        onUnregister: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = draft
        self.engineModel = engineModel
        self.canSubmit = canSubmit
        self.isSaving = isSaving
        self.onSave = onSave
        self.onUnregister = onUnregister
        self.onCancel = onCancel
    }

    var body: some View {
        ZStack {
            CarPalCanvas()
            ScrollView {
                VStack(spacing: 18) {
                    identityCard
                    editableDetailsCard
                    unregisterCard
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Edit vehicle")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { saveBar }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel).disabled(isSaving)
            }
        }
        .interactiveDismissDisabled(isSaving)
        .onChange(of: draft.trim) { _, _ in
            if !draft.colour.isEmpty, !colourOptions.contains(draft.colour) {
                draft.colour = ""
            }
        }
        .confirmationDialog(
            "Unregister this vehicle?",
            isPresented: $showsUnregisterConfirmation,
            titleVisibility: .visible
        ) {
            Button("Unregister and clear data", role: .destructive, action: onUnregister)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes the saved vehicle and its scan history. You will return to vehicle registration.")
        }
    }

    private var identityCard: some View {
        CarPalCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Vehicle identity", systemImage: "checkmark.shield.fill")
                    .font(.carPalSection)
                Text("Identity comes from OBD and VIN decoding and cannot be changed here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                identityRow("Make", draft.make)
                identityRow("Model", draft.variant)
                identityRow("Model year", draft.modelYear)
                identityRow("Engine", engineModel)
                identityRow("Fuel type", draft.fuelType)
            }
        }
    }

    private var editableDetailsCard: some View {
        CarPalCard {
            VStack(alignment: .leading, spacing: 15) {
                Text("Vehicle details").font(.carPalSection)
                pickerField(
                    "Trim",
                    selection: $draft.trim,
                    options: trimOptions,
                    prompt: trimOptions.isEmpty ? "No catalog match" : "Select trim",
                    isDisabled: trimOptions.isEmpty
                )
                pickerField(
                    "Exterior colour",
                    selection: $draft.colour,
                    options: colourOptions,
                    prompt: draft.trim.isEmpty && !trimOptions.isEmpty
                        ? "Select a trim first"
                        : "Select colour",
                    isDisabled: draft.trim.isEmpty && !trimOptions.isEmpty
                )
                VStack(alignment: .leading, spacing: 6) {
                    Text("Mileage").font(.subheadline.weight(.semibold))
                    TextField("Current odometer", text: $draft.mileage)
                        .keyboardType(.decimalPad)
                        .padding(.horizontal, 13)
                        .frame(minHeight: 47)
                        .background(.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 13))
                }
            }
        }
    }

    @State private var showsUnregisterConfirmation = false

    private var unregisterCard: some View {
        CarPalCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Remove vehicle").font(.carPalSection)
                Text("Clear this vehicle and its scan history from CarPal.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Unregister vehicle", role: .destructive) {
                    showsUnregisterConfirmation = true
                }
                .font(.body.weight(.semibold))
            }
        }
    }

    private var trimOptions: [String] {
        selectionPolicy.trimOptions(for: VehicleRegistrationDraft(profile: draft))
    }

    private var colourOptions: [String] {
        selectionPolicy.colourOptions(for: VehicleRegistrationDraft(profile: draft))
    }

    private func identityRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value.isEmpty ? "Unknown" : value).fontWeight(.semibold)
        }
        .font(.subheadline)
    }

    private func pickerField(
        _ label: String,
        selection: Binding<String>,
        options: [String],
        prompt: String,
        isDisabled: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline.weight(.semibold))
            Picker(label, selection: selection) {
                Text(prompt).tag("")
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, minHeight: 47, alignment: .leading)
            .padding(.horizontal, 13)
            .background(.white.opacity(isDisabled ? 0.45 : 0.76), in: RoundedRectangle(cornerRadius: 13))
            .disabled(isDisabled)
        }
    }

    private var saveBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: onSave) {
                Text(isSaving ? "Saving changes..." : "Save changes")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(CarPalColor.accent)
            .disabled(!canSubmit || isSaving)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial)
    }
}

#if DEBUG
    #Preview {
        @Previewable @State var draft = VehicleDraft.lexusNXPreview
        NavigationStack {
            EditVehicleView(
                draft: $draft,
                engineModel: "8AR-FTS",
                canSubmit: true,
                onSave: {},
                onUnregister: {},
                onCancel: {}
            )
        }
    }
#endif
