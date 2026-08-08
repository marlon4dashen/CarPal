import SwiftUI

struct VehicleFormView: View {
    @Binding private var draft: VehicleDraft
    private let fieldErrors: VehicleFormFieldErrors

    @FocusState private var focusedField: VehicleFormField?
    @State private var showsOptionalDetails: Bool

    init(
        draft: Binding<VehicleDraft>,
        fieldErrors: VehicleFormFieldErrors = .init()
    ) {
        _draft = draft
        self.fieldErrors = fieldErrors

        let value = draft.wrappedValue
        _showsOptionalDetails = State(
            initialValue: !value.trim.isEmpty
                || !value.colour.isEmpty
                || !value.fuelType.isEmpty
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                introduction
                requiredDetails
                optionalDetails
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(background)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: draft.make) { _, newMake in
            guard VehicleProfileOptions.canonicalModel(draft.model, for: newMake) == nil else {
                return
            }
            draft.model = ""
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
    }

    private var introduction: some View {
        HStack(spacing: 14) {
            Image(systemName: "car.side.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(CarPalColor.accent, in: RoundedRectangle(cornerRadius: 15))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Your vehicle, at a glance")
                    .font(.headline)
                    .foregroundStyle(CarPalColor.ink)
                Text("Add the details CarPal needs to identify and assess your vehicle.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(CarPalColor.canvas, in: RoundedRectangle(cornerRadius: 22))
    }

    private var requiredDetails: some View {
        VehicleFormCard(
            title: "Vehicle identity",
            subtitle: "Required for scans and vehicle-specific guidance"
        ) {
            vehicleField(
                "Nickname",
                placeholder: "My daily driver",
                text: $draft.nickname,
                field: .nickname,
                contentType: .nickname,
                capitalization: .words
            )

            pickerField(
                "Make",
                selection: makeSelection,
                options: VehicleProfileOptions.makes,
                prompt: "Select make",
                field: .make,
                helpText: "CarPal currently supports Lexus and BMW profiles."
            )

            pickerField(
                "Model",
                selection: modelSelection,
                options: VehicleProfileOptions.models(for: draft.make),
                prompt: draft.make.isEmpty ? "Select a make first" : "Select model",
                field: .model,
                isDisabled: draft.make.isEmpty,
                helpText: draft.make.isEmpty
                    ? "Choose a make to see its supported models."
                    : "Only supported \(draft.make) models are shown."
            )

            vehicleField(
                "Model year",
                placeholder: "2020",
                text: $draft.modelYear,
                field: .modelYear,
                keyboardType: .numberPad
            )

            vehicleField(
                "VIN or licence plate",
                placeholder: "Enter either identifier",
                text: $draft.vinOrPlate,
                field: .vinOrPlate,
                capitalization: .characters,
                helpText: "Used to distinguish your vehicle. This is stored with your local profile."
            )

            vehicleField(
                "Current mileage",
                placeholder: "48200",
                text: $draft.mileage,
                field: .mileage,
                keyboardType: .decimalPad,
                helpText: "Enter the current odometer reading."
            )
        }
    }

    private var optionalDetails: some View {
        VehicleFormCard(
            title: "Optional details",
            subtitle: "Helps personalize your vehicle profile"
        ) {
            DisclosureGroup(isExpanded: $showsOptionalDetails) {
                VStack(spacing: 16) {
                    vehicleField(
                        "Trim",
                        placeholder: "Luxury",
                        text: $draft.trim,
                        field: .trim,
                        capitalization: .words
                    )

                    pickerField(
                        "Colour",
                        selection: colourSelection,
                        options: VehicleProfileOptions.colours,
                        prompt: "Select colour",
                        field: .colour,
                        helpText: "Used to colour the vehicle preview."
                    )

                    pickerField(
                        "Fuel type",
                        selection: fuelTypeSelection,
                        options: VehicleProfileOptions.fuelTypes,
                        prompt: "Select fuel type",
                        field: .fuelType,
                        helpText: "Choose Other if the exact type is not listed."
                    )
                }
                .padding(.top, 16)
            } label: {
                HStack {
                    Text(showsOptionalDetails ? "Hide details" : "Add trim, colour, and fuel type")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CarPalColor.ink)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .tint(CarPalColor.accent)
        }
    }

    private func pickerField(
        _ title: String,
        selection: Binding<String>,
        options: [String],
        prompt: String,
        field: VehicleFormField,
        isDisabled: Bool = false,
        helpText: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CarPalColor.ink)

            Picker(title, selection: selection) {
                Text(prompt).tag("")
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(isDisabled ? CarPalColor.secondaryInk.opacity(0.55) : CarPalColor.ink)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .padding(.horizontal, 14)
            .background(
                Color.white.opacity(isDisabled ? 0.46 : 0.82),
                in: RoundedRectangle(cornerRadius: 13)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .stroke(
                        fieldErrors[field] == nil
                            ? CarPalColor.hairline
                            : Color.red.opacity(0.75),
                        lineWidth: fieldErrors[field] == nil ? 1 : 1.5
                    )
            }
            .disabled(isDisabled)
            .accessibilityLabel(field.accessibilityLabel)

            if let error = fieldErrors[field] {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel("\(field.accessibilityLabel) error: \(error)")
            } else if let helpText {
                Text(helpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var colourSelection: Binding<String> {
        Binding(
            get: { VehicleProfileOptions.canonicalColour(for: draft.colour) ?? "" },
            set: { draft.colour = $0 }
        )
    }

    private var makeSelection: Binding<String> {
        Binding(
            get: { VehicleProfileOptions.canonicalMake(for: draft.make) ?? "" },
            set: { draft.make = $0 }
        )
    }

    private var modelSelection: Binding<String> {
        Binding(
            get: {
                VehicleProfileOptions.canonicalModel(draft.model, for: draft.make) ?? ""
            },
            set: { draft.model = $0 }
        )
    }

    private var fuelTypeSelection: Binding<String> {
        Binding(
            get: { VehicleProfileOptions.canonicalFuelType(for: draft.fuelType) ?? "" },
            set: { draft.fuelType = $0 }
        )
    }

    @ViewBuilder
    private func vehicleField(
        _ title: String,
        placeholder: String,
        text: Binding<String>,
        field: VehicleFormField,
        keyboardType: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        capitalization: TextInputAutocapitalization = .never,
        helpText: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CarPalColor.ink)

            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .keyboardType(keyboardType)
                .textContentType(contentType)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled()
                .focused($focusedField, equals: field)
                .submitLabel(field.next == nil ? .done : .next)
                .onSubmit {
                    focusedField = field.next
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(
                    Color.white.opacity(0.82),
                    in: RoundedRectangle(cornerRadius: 13)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(
                            fieldErrors[field] == nil
                                ? CarPalColor.hairline
                                : Color.red.opacity(0.75),
                            lineWidth: fieldErrors[field] == nil ? 1 : 1.5
                        )
                }
                .accessibilityLabel(field.accessibilityLabel)

            if let error = fieldErrors[field] {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel("\(field.accessibilityLabel) error: \(error)")
            } else if let helpText {
                Text(helpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                CarPalColor.canvasHighlight,
                CarPalColor.canvas.opacity(0.58),
                CarPalColor.canvasHighlight
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct VehicleFormCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(CarPalColor.ink)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.74), lineWidth: 1)
        }
        .shadow(color: CarPalColor.ink.opacity(0.06), radius: 16, y: 8)
    }
}

#if DEBUG
    #Preview("Vehicle form") {
        @Previewable @State var draft = VehicleDraft.lexusNXPreview

        NavigationStack {
            VehicleFormView(draft: $draft)
                .navigationTitle("Vehicle")
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    #Preview("Validation errors") {
        @Previewable @State var draft = VehicleDraft()

        NavigationStack {
            VehicleFormView(
                draft: $draft,
                fieldErrors: VehicleFormFieldErrors([
                    .nickname: "Enter a nickname.",
                    .modelYear: "Enter a four-digit year."
                ])
            )
            .navigationTitle("Vehicle")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
#endif
