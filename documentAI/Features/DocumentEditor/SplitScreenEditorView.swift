//
//  SplitScreenEditorView.swift
//  documentAI
//
//  Custom vertical split-screen editor with drag handle
//  Top: PDF viewer, Bottom: Form fields
//

import SwiftUI
import PDFKit

struct SplitScreenEditorView: View {
    @StateObject private var viewModel: DocumentViewModel
    @State private var splitRatio: CGFloat = 0.5 // 50% split initially
    @State private var isDragging = false
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var focusedFieldUUID: UUID?
    
    // Hybrid pipeline state
    @State private var showQuickLook = false
    @State private var showFallbackAlert = false
    @State private var hasAcroFormFields = false
    
    // CommonForms backend-generated PDF
    @State private var commonFormsPdfURL: URL?
    @State private var commonFormsFields: [DetectedField] = []
    
    let onBack: () -> Void
    
    init(
        components: [FieldComponent],
        fieldRegions: [FieldRegion],
        documentId: String,
        selectedFile: DocumentModel?,
        pdfURL: URL?,
        commonFormsPdfURL: URL? = nil,
        commonFormsFields: [DetectedField] = [],
        onBack: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: DocumentViewModel(
            components: components,
            fieldRegions: fieldRegions,
            documentId: documentId,
            selectedFile: selectedFile,
            pdfURL: pdfURL
        ))
        self.onBack = onBack
        self._commonFormsPdfURL = State(initialValue: commonFormsPdfURL)
        self._commonFormsFields = State(initialValue: commonFormsFields)
        
        // Use CommonForms PDF if available, otherwise detect AcroForm fields
        let effectivePdfURL = commonFormsPdfURL ?? pdfURL
        if let effectivePdfURL = effectivePdfURL,
           let document = PDFDocument(url: effectivePdfURL) {
            _hasAcroFormFields = State(initialValue: document.hasAcroFormFields)
            if !document.hasAcroFormFields && commonFormsPdfURL == nil {
                _showFallbackAlert = State(initialValue: true)
            }
        }
        
        // Log CommonForms fields if provided
        if !commonFormsFields.isEmpty {
            print("📝 ===== COMMONFORMS FIELDS IN EDITOR =====")
            for (index, field) in commonFormsFields.enumerated() {
                print("  [\(index)] id: \(field.id)")
                print("       type: \(field.type)")
                print("       page: \(field.page)")
                print("       bbox: \(field.bbox)")
                print("       label: \(field.label ?? "nil")")
            }
            print("📝 ===== TOTAL: \(commonFormsFields.count) FIELDS =====")
        }
        
        // Log CommonForms PDF URL if provided
        if let cfUrl = commonFormsPdfURL {
            print("📄 CommonForms PDF URL: \(cfUrl.path)")
        }
    }
    
    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            
            VStack(spacing: 0) {
                headerSection
                
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        // Top Pane: PDF Viewer
                        if let pdfURL = viewModel.pdfURL {
                            pdfViewerPane(height: geometry.size.height * splitRatio)
                        } else {
                            noPDFPlaceholder(height: geometry.size.height * splitRatio)
                        }
                        
                        // Drag Handle
                        dragHandle
                        
                        // Bottom Pane: Form Fields
                        formFieldsPane(height: geometry.size.height * (1 - splitRatio))
                    }
                }
            }
            
            if viewModel.submitting {
                submittingOverlay
            }
        }
        .alert(item: $viewModel.alertState) { alertState in
            createAlert(from: alertState)
        }
        .alert("PDF Mode", isPresented: $showFallbackAlert) {
            Button("Use Synthetic Fields") {
                // Stay in current view with synthetic widgets
                showFallbackAlert = false
            }
            Button("Open in Files Mode") {
                showQuickLook = true
            }
            Button("Cancel", role: .cancel) {
                // Stay in current view
            }
        } message: {
            if !viewModel.fieldRegions.isEmpty {
                Text("This PDF has no native form fields, but we detected \(viewModel.fieldRegions.count) fields using Vision. You can edit them here or use Apple's QuickLook.")
            } else {
                Text("This PDF has no interactive fields. Would you like to use Apple's built-in form detector?")
            }
        }
        .fullScreenCover(isPresented: $showQuickLook) {
            if let pdfURL = viewModel.pdfURL {
                QuickLookPDFView(url: pdfURL)
                    .ignoresSafeArea()
            }
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
            
            Button {
                viewModel.saveProgress()
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.Colors.primary)
                    .padding(Theme.Spacing.sm)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(Color.white.opacity(0.95))
    }
    
    // MARK: - PDF Viewer Pane
    private func pdfViewerPane(height: CGFloat) -> some View {
        GeometryReader { geometry in
            ZStack {
                // Prefer CommonForms PDF if available
                let effectiveURL = commonFormsPdfURL ?? viewModel.pdfURL
                
                if let url = effectiveURL {
                    if hasAcroFormFields || !viewModel.fieldRegions.isEmpty || commonFormsPdfURL != nil {
                        // Mode selection based on hasAcroFormFields flag or CommonForms PDF
                        PDFKitRepresentedView(
                            pdfURL: url,
                            formValues: $viewModel.formValues,
                            detectedFields: viewModel.fieldRegions,
                            fieldIdToUUID: viewModel.fieldIdToUUID,
                            acroformDetected: hasAcroFormFields || commonFormsPdfURL != nil,
                            onFieldTapped: { uuid in
                                handleFieldTapped(uuid: uuid)
                            }
                        )
                        .onAppear {
                            if commonFormsPdfURL != nil {
                                print("📄 Loading CommonForms-generated fillable PDF")
                            }
                        }
                    } else {
                        // Show message that QuickLook is available
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("No Interactive Fields Detected")
                                .font(.headline)
                                .foregroundColor(.gray)
                            Text("Tap 'Open in Files Mode' to use Apple's form detector")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            Button("Open in Files Mode") {
                                showQuickLook = true
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .frame(height: height)
        .background(Color.gray.opacity(0.1))
    }
    
    // MARK: - No PDF Placeholder
    private func noPDFPlaceholder(height: CGFloat) -> some View {
        VStack {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("PDF Preview Unavailable")
                .font(Theme.Typography.bodyMedium)
                .foregroundColor(.gray)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
    }
    

    
    // MARK: - Drag Handle
    private var dragHandle: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 20)
            
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray)
                .frame(width: 40, height: 4)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    // Update split ratio based on drag
                    // Clamp between 0.2 and 0.8
                    let newRatio = splitRatio + (value.translation.height / UIScreen.main.bounds.height)
                    splitRatio = min(max(newRatio, 0.2), 0.8)
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
    }
    
    // MARK: - Form Fields Pane
    private func formFieldsPane(height: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(Array(viewModel.components.enumerated()), id: \.element.id) { index, component in
                        if let uuid = viewModel.fieldIdToUUID[component.id] {
                            fieldView(for: component, uuid: uuid)
                                .id(uuid)
                        }
                    }
                    
                    submitButton
                }
                .padding(Theme.Spacing.lg)
            }
            .frame(height: height)
            .background(Color.white.opacity(0.95))
            .onAppear {
                scrollProxy = proxy
            }
        }
    }
    
    // MARK: - Field View
    @ViewBuilder
    private func fieldView(for component: FieldComponent, uuid: UUID) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(component.label)
                .font(Theme.Typography.bodyMedium)
                .foregroundColor(Theme.Colors.textPrimary)
            
            switch component.type {
            case .text, .email, .phone, .number:
                textFieldView(for: component, uuid: uuid)
            case .textarea, .multiline:
                textAreaView(for: component, uuid: uuid)
            case .select:
                selectView(for: component, uuid: uuid)
            case .checkbox:
                checkboxView(for: component, uuid: uuid)
            case .date:
                dateFieldView(for: component, uuid: uuid)
            case .signature:
                textFieldView(for: component, uuid: uuid)
            case .button, .unknown:
                EmptyView()
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    // MARK: - Text Field View
    private func textFieldView(for component: FieldComponent, uuid: UUID) -> some View {
        TextField(
            component.placeholder ?? "",
            text: Binding(
                get: { viewModel.getFieldValue(uuid: uuid) },
                set: { viewModel.updateFieldValue(uuid: uuid, value: $0) }
            )
        )
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .keyboardType(keyboardType(for: component.type))
        .focused($focusedFieldUUID, equals: uuid)
    }
    
    // MARK: - Text Area View
    private func textAreaView(for component: FieldComponent, uuid: UUID) -> some View {
        TextEditor(
            text: Binding(
                get: { viewModel.getFieldValue(uuid: uuid) },
                set: { viewModel.updateFieldValue(uuid: uuid, value: $0) }
            )
        )
        .frame(minHeight: 100)
        .padding(Theme.Spacing.sm)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
        .focused($focusedFieldUUID, equals: uuid)
    }
    
    // MARK: - Select View
    private func selectView(for component: FieldComponent, uuid: UUID) -> some View {
        Picker(
            component.placeholder ?? "Select",
            selection: Binding(
                get: { viewModel.getFieldValue(uuid: uuid) },
                set: { viewModel.updateFieldValue(uuid: uuid, value: $0) }
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
    private func checkboxView(for component: FieldComponent, uuid: UUID) -> some View {
        Toggle(
            isOn: Binding(
                get: { viewModel.getFieldValue(uuid: uuid) == "true" },
                set: { viewModel.updateFieldValue(uuid: uuid, value: $0 ? "true" : "false") }
            )
        ) {
            EmptyView()
        }
        .toggleStyle(SwitchToggleStyle())
    }
    
    // MARK: - Date Field View
    private func dateFieldView(for component: FieldComponent, uuid: UUID) -> some View {
        DatePicker(
            "",
            selection: Binding(
                get: {
                    let dateString = viewModel.getFieldValue(uuid: uuid)
                    if let date = ISO8601DateFormatter().date(from: dateString) {
                        return date
                    }
                    return Date()
                },
                set: {
                    let dateString = ISO8601DateFormatter().string(from: $0)
                    viewModel.updateFieldValue(uuid: uuid, value: dateString)
                }
            ),
            displayedComponents: .date
        )
        .datePickerStyle(CompactDatePickerStyle())
    }
    
    // MARK: - Submit Button
    private var submitButton: some View {
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
    
    // MARK: - Handle Field Tapped
    private func handleFieldTapped(uuid: UUID) {
        // Scroll to field and focus it
        withAnimation {
            scrollProxy?.scrollTo(uuid, anchor: .center)
        }
        
        // Focus the field after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            focusedFieldUUID = uuid
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
