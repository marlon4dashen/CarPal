import SwiftUI

struct VehicleSetupView: View {
    @Binding private var draft: VehicleDraft
    private let fieldErrors: VehicleFormFieldErrors
    private let canSubmit: Bool
    private let isSaving: Bool
    private let onSave: () -> Void
    private let onCancel: (() -> Void)?

    init(
        draft: Binding<VehicleDraft>,
        fieldErrors: VehicleFormFieldErrors = .init(),
        canSubmit: Bool,
        isSaving: Bool = false,
        onSave: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        _draft = draft
        self.fieldErrors = fieldErrors
        self.canSubmit = canSubmit
        self.isSaving = isSaving
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VehicleFormView(draft: $draft, fieldErrors: fieldErrors)
            .navigationTitle("Set up your vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                saveBar
            }
            .toolbar {
                if let onCancel {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onCancel)
                            .disabled(isSaving)
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
    }

    private var saveBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: onSave) {
                HStack(spacing: 10) {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isSaving ? "Saving vehicle..." : "Save vehicle")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(CarPalColor.accent)
            .disabled(!canSubmit || isSaving)
            .accessibilityHint(
                canSubmit
                    ? "Saves this vehicle profile"
                    : "Complete the required vehicle details before saving"
            )
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
            VehicleSetupView(
                draft: $draft,
                canSubmit: true,
                onSave: {}
            )
        }
    }
#endif
