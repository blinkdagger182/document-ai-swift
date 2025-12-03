//
//  FillDocumentView.swift
//  documentAI
//
//  View for filling document form fields
//

import SwiftUI

struct FillDocumentView: View {
    @StateObject private var viewModel: FillDocumentViewModel
    
    let onBack: () -> Void
    let onUploadAnother: () -> Void
    
    init(
        components: [FieldComponent],
        fieldMap: FieldMap,
        formData: FormData,
        documentId: String,
        selectedFile: DocumentModel?,
        fieldRegions: [FieldRegion] = [],
        onBack: @escaping () -> Void,
        onUploadAnother: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: FillDocumentViewModel(
            components: components,
            fieldMap: fieldMap,
            formData: formData,
            documentId: documentId,
            selectedFile: selectedFile,
            fieldRegions: fieldRegions
        ))
        self.onBack = onBack
        self.onUploadAnother = onUploadAnother
    }
    
    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            
            VStack(spacing: 0) {
                headerSection
                
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        ForEach(viewModel.components) { component in
                            fieldView(for: component)
                        }
                        
                        formActionsSection
                    }
                    .padding(Theme.Spacing.lg)
                }
            }
            
            if viewModel.submitting {
                submittingOverlay
            }
        }
        .alert(item: $viewModel.alertState) { alertState in
            createAlert(from: alertState)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Button {
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 24))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(Theme.Spacing.sm)
            }
            
            Spacer()
            
            Text("Fill Document")
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.textPrimary)
            
            Spacer()
            
            Color.clear
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(Color.white.opacity(0.9))
    }
    
    // MARK: - Field View
    @ViewBuilder
    private func fieldView(for component: FieldComponent) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(component.label)
                .font(Theme.Typography.bodyMedium)
                .foregroundColor(Theme.Colors.textPrimary)
            
            switch component.type {
            case .text, .email, .phone, .number:
                textFieldView(for: component)
            case .textarea:
                textAreaView(for: component)
            case .select:
                selectView(for: component)
            case .checkbox:
                checkboxView(for: component)
            case .date:
                dateFieldView(for: component)
            case .button:
                EmptyView()
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    // MARK: - Text Field View
    private func textFieldView(for component: FieldComponent) -> some View {
        TextField(
            component.placeholder ?? "",
            text: Binding(
                get: { viewModel.formData[component.id] ?? "" },
                set: { viewModel.updateFieldValue(id: component.id, value: $0) }
            )
        )
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .keyboardType(keyboardType(for: component.type))
    }
    
    // MARK: - Text Area View
    private func textAreaView(for component: FieldComponent) -> some View {
        TextEditor(
            text: Binding(
                get: { viewModel.formData[component.id] ?? "" },
                set: { viewModel.updateFieldValue(id: component.id, value: $0) }
            )
        )
        .frame(minHeight: 100)
        .padding(Theme.Spacing.sm)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
    }
    
    // MARK: - Select View
    private func selectView(for component: FieldComponent) -> some View {
        Picker(
            component.placeholder ?? "Select",
            selection: Binding(
                get: { viewModel.formData[component.id] ?? "" },
                set: { viewModel.updateFieldValue(id: component.id, value: $0) }
            )
        ) {
            Text("Select").tag("")
            ForEach(component.options ?? [], id: \.self) { option in
                Text(option).tag(option)
            }
        }
        .pickerStyle(MenuPickerStyle())
        .padding(Theme.Spacing.sm)
        .background(Theme.Colors.background)
        .cornerRadius(Theme.CornerRadius.sm)
    }
    
    // MARK: - Checkbox View
    private func checkboxView(for component: FieldComponent) -> some View {
        Toggle(
            isOn: Binding(
                get: { viewModel.formData[component.id] == "true" },
                set: { viewModel.updateFieldValue(id: component.id, value: $0 ? "true" : "false") }
            )
        ) {
            EmptyView()
        }
        .toggleStyle(CheckboxToggleStyle())
    }
    
    // MARK: - Date Field View
    private func dateFieldView(for component: FieldComponent) -> some View {
        DatePicker(
            "",
            selection: Binding(
                get: {
                    if let dateString = viewModel.formData[component.id],
                       let date = ISO8601DateFormatter().date(from: dateString) {
                        return date
                    }
                    return Date()
                },
                set: {
                    let dateString = ISO8601DateFormatter().string(from: $0)
                    viewModel.updateFieldValue(id: component.id, value: dateString)
                }
            ),
            displayedComponents: .date
        )
        .datePickerStyle(CompactDatePickerStyle())
    }
    
    // MARK: - Form Actions Section
    private var formActionsSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            Button {
                Task {
                    await viewModel.submitAndGeneratePDF()
                }
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    if viewModel.submitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "checkmark.circle")
                        Text("Submit & Generate PDF")
                            .font(Theme.Typography.bodySemibold)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.lg)
                .background(Theme.Colors.primary)
                .cornerRadius(Theme.CornerRadius.md)
                .shadow(
                    color: Theme.Shadows.button.color,
                    radius: Theme.Shadows.button.radius,
                    x: Theme.Shadows.button.x,
                    y: Theme.Shadows.button.y
                )
                .opacity(viewModel.submitting ? 0.6 : 1.0)
            }
            .disabled(viewModel.submitting)
            
            Button {
                viewModel.saveProgress()
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Save Progress")
                        .font(Theme.Typography.bodySemibold)
                }
                .foregroundColor(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.lg)
                .background(Color.clear)
                .cornerRadius(Theme.CornerRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                        .stroke(Theme.Colors.border, lineWidth: 1)
                )
            }
            .disabled(viewModel.submitting)
        }
        .padding(.top, Theme.Spacing.lg)
    }
    
    // MARK: - Submitting Overlay
    private var submittingOverlay: some View {
        ZStack {
            Color.white.opacity(0.9)
                .ignoresSafeArea()
            
            VStack(spacing: Theme.Spacing.lg) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.primary))
                    .scaleEffect(1.5)
                
                Text("Generating filled PDF...")
                    .font(Theme.Typography.bodySemibold)
                    .foregroundColor(Theme.Colors.textPrimary)
            }
        }
    }
    
    // MARK: - Helper Functions
    private func keyboardType(for fieldType: FieldType) -> UIKeyboardType {
        switch fieldType {
        case .email:
            return .emailAddress
        case .phone:
            return .phonePad
        case .number:
            return .numberPad
        default:
            return .default
        }
    }
    
    private func createAlert(from alertState: FillAlertState) -> Alert {
        if alertState.actions.count > 1 {
            return Alert(
                title: Text(alertState.title),
                message: Text(alertState.message),
                primaryButton: .default(Text(alertState.actions[0].title)) {
                    alertState.actions[0].handler()
                },
                secondaryButton: .default(Text(alertState.actions[1].title)) {
                    alertState.actions[1].handler()
                    if alertState.actions[1].title == "Upload Another" {
                        onUploadAnother()
                    }
                }
            )
        } else {
            return Alert(
                title: Text(alertState.title),
                message: Text(alertState.message),
                dismissButton: .default(Text(alertState.actions.first?.title ?? "OK")) {
                    alertState.actions.first?.handler()
                }
            )
        }
    }
}

// MARK: - Checkbox Toggle Style
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(configuration.isOn ? Theme.Colors.primary : Theme.Colors.textSecondary)
                    .font(.system(size: 24))
                configuration.label
            }
        }
    }
}

#Preview {
    FillDocumentView(
        components: [
            FieldComponent(id: "1", type: .text, label: "Name", placeholder: "Enter name", options: nil, value: nil),
            FieldComponent(id: "2", type: .email, label: "Email", placeholder: "Enter email", options: nil, value: nil)
        ],
        fieldMap: [:],
        formData: [:],
        documentId: "test",
        selectedFile: nil,
        onBack: {},
        onUploadAnother: {}
    )
}
