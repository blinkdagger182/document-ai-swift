//
//  DocumentChatView.swift
//  documentAI
//
//  Main document chat view with Instagram-style drawer
//  Combines PDF viewer with AI chat interface
//

import SwiftUI
import PDFKit

struct DocumentChatView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var chatViewModel: ChatViewModel
    @FocusState var isTextFieldFocused: Bool
    
    // PDF State
    @State private var currentPDFDocument: PDFDocument? = nil
    @State private var currentPDFPage: Int = 0
    @State private var isZoomedIn: Bool = false
    
    // Chat Drawer State (Instagram-style bottom drawer)
    @State private var drawerHeight: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @State private var hasInitialized = false
    
    // Document data
    let documentId: String
    let selectedFile: DocumentModel?
    let pdfURL: URL?
    let commonFormsPdfURL: URL?
    let commonFormsFields: [DetectedField]
    let onBack: () -> Void
    
    init(
        documentId: String,
        selectedFile: DocumentModel?,
        pdfURL: URL?,
        commonFormsPdfURL: URL?,
        commonFormsFields: [DetectedField],
        onBack: @escaping () -> Void
    ) {
        self.documentId = documentId
        self.selectedFile = selectedFile
        self.pdfURL = pdfURL
        self.commonFormsPdfURL = commonFormsPdfURL
        self.commonFormsFields = commonFormsFields
        self.onBack = onBack
        
        // Initialize chat with document context
        let systemPrompt = """
        You are an AI assistant helping users fill out PDF forms.
        
        Context:
        - Document: \(selectedFile?.name ?? "Unknown")
        - Total fields detected: \(commonFormsFields.count)
        
        Your role:
        1. Ask clarifying questions to gather information
        2. Suggest values for form fields based on user input
        3. Be concise and helpful
        4. Guide users through the form filling process
        
        Be friendly and accurate.
        """
        
        let apiKey = AppConfig.openAIKey
        let api = ChatGPTAPI(apiKey: apiKey, systemPrompt: systemPrompt)
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(api: api))
    }
    
    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let currentDrawerHeight = drawerHeight + dragOffset
            let pdfContainerHeight = screenHeight - currentDrawerHeight
            
            ZStack(alignment: .bottom) {
                // PDF Viewer - dynamically sized based on drawer position
                pdfReelsView
                    .frame(height: pdfContainerHeight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .zIndex(0)
                
                // Bottom Drawer: Chat Interface (Instagram Chat style)
                chatDrawerView(screenHeight: screenHeight)
                    .zIndex(1)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onAppear {
                if !hasInitialized {
                    loadPDF()
                    // Start with drawer at half screen
                    drawerHeight = screenHeight * 0.5
                    hasInitialized = true
                }
            }
        }
    }
    
    // MARK: - PDF Reels View (Top Half)
    
    var pdfReelsView: some View {
        Group {
            if let pdfDocument = currentPDFDocument {
                VStack(spacing: 0) {
                    // PDF Toolbar
                    pdfToolbar(pageCount: pdfDocument.pageCount)
                        .background(Color(UIColor.systemBackground).opacity(0.95))
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    
                    // PDF Container with annotations
                    ZStack(alignment: .bottomTrailing) {
                        if !commonFormsFields.isEmpty && FeatureFlags.showBoundingBoxes {
                            // Use annotated PDF view
                            AnnotatedPDFView(
                                pdfURL: commonFormsPdfURL ?? pdfURL ?? URL(fileURLWithPath: ""),
                                detectedFields: commonFormsFields,
                                currentPage: $currentPDFPage,
                                isZoomedIn: $isZoomedIn,
                                onTap: {
                                    // Minimize drawer when PDF is tapped
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        drawerHeight = 120
                                    }
                                }
                            )
                        } else {
                            // Use regular PDF view
                            PDFViewWrapper(
                                pdfDocument: pdfDocument,
                                currentPage: $currentPDFPage,
                                isZoomedIn: $isZoomedIn,
                                onTap: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        drawerHeight = 120
                                    }
                                }
                            )
                        }
                        
                        // Zoom out button
                        if isZoomedIn {
                            Button {
                                zoomOutPDF()
                            } label: {
                                Image(systemName: "arrow.down.right.and.arrow.up.left")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            .padding(.trailing, 16)
                            .padding(.bottom, 16)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            } else {
                // Placeholder when no PDF
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No PDF Loaded")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.systemGray6))
            }
        }
    }
    
    func zoomOutPDF() {
        NotificationCenter.default.post(name: NSNotification.Name("ZoomOutPDF"), object: nil)
    }
    
    func pdfToolbar(pageCount: Int) -> some View {
        HStack(spacing: 8) {
            // Back button
            Button {
                onBack()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
                    .frame(width: 50, height: 50)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(12)
            }
            
            Spacer()
            
            // Page navigation
            HStack(spacing: 12) {
                Button {
                    if currentPDFPage > 0 {
                        currentPDFPage -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18))
                        .foregroundColor(currentPDFPage == 0 ? .gray : .primary)
                }
                .disabled(currentPDFPage == 0)
                
                VStack(spacing: 2) {
                    Text("\(currentPDFPage + 1) / \(pageCount)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("Pages")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Button {
                    if currentPDFPage < pageCount - 1 {
                        currentPDFPage += 1
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18))
                        .foregroundColor(currentPDFPage >= pageCount - 1 ? .gray : .primary)
                }
                .disabled(currentPDFPage >= pageCount - 1)
            }
            
            Spacer()
            
            // Options menu
            Menu {
                Button {
                    // Download PDF
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                }
                
                Button {
                    chatViewModel.clearMessages()
                } label: {
                    Label("Clear Chat", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 50, height: 50)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Chat Drawer View (Bottom - Instagram Style)
    
    func chatDrawerView(screenHeight: CGFloat) -> some View {
        let minHeight: CGFloat = 120 // Minimized
        let midHeight: CGFloat = screenHeight * 0.5 // Half screen
        let maxHeight: CGFloat = screenHeight - 100 // Almost full screen
        
        let currentHeight = drawerHeight + dragOffset
        let isMinimized = currentHeight <= minHeight + 20
        
        return VStack(spacing: 0) {
            // Drawer Handle
            drawerHandle
                .gesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .global)
                        .onChanged { value in
                            isTextFieldFocused = false
                            let newOffset = -value.translation.height
                            dragOffset = newOffset
                        }
                        .onEnded { value in
                            let dragDistance = -value.translation.height
                            let newHeight = drawerHeight + dragDistance
                            
                            let velocityY = value.predictedEndTranslation.height - value.translation.height
                            let velocity = -velocityY / 100
                            
                            let targetHeight = snapToHeight(
                                height: newHeight,
                                velocity: velocity,
                                minHeight: minHeight,
                                midHeight: midHeight,
                                maxHeight: maxHeight
                            )
                            
                            withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                                drawerHeight = targetHeight
                                dragOffset = 0
                            }
                        }
                )
            
            // Chat Content
            if !isMinimized {
                ScrollViewReader { proxy in
                    VStack(spacing: 0) {
                        // Messages Area
                        if !chatViewModel.messages.isEmpty {
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(chatViewModel.messages) { message in
                                        MessageRowView(message: message) { message in
                                            Task { @MainActor in
                                                await chatViewModel.retry(message: message)
                                            }
                                        }
                                    }
                                }
                                .padding()
                            }
                        } else {
                            // Empty state
                            VStack(spacing: 16) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray.opacity(0.5))
                                Text("Ask AI to help fill this form")
                                    .font(.title3)
                                    .foregroundColor(.primary)
                                Text("Example: 'What information do you need?'")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                if !commonFormsFields.isEmpty {
                                    Text("\(commonFormsFields.count) fields detected")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 8)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                        }
                        
                        Divider()
                        
                        // Input Area
                        chatInputView(proxy: proxy, midHeight: midHeight)
                    }
                    .onChange(of: chatViewModel.messages.last?.responseText) { _ in
                        scrollToBottom(proxy: proxy)
                    }
                }
            } else {
                // When minimized, only show input area
                Spacer()
                chatInputView(proxy: nil, midHeight: midHeight)
            }
        }
        .frame(height: max(minHeight, min(maxHeight, currentHeight)))
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: -5)
        )
    }
    
    var drawerHandle: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
        }
        .frame(height: 20)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
    
    func chatInputView(proxy: ScrollViewProxy?, midHeight: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 12) {
            TextField("Message", text: $chatViewModel.inputMessage, axis: .vertical)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(20)
                .focused($isTextFieldFocused)
                .disabled(chatViewModel.isInteracting)
                .lineLimit(1...5)
                .onChange(of: isTextFieldFocused) { isFocused in
                    if isFocused && drawerHeight < midHeight - 50 {
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                            drawerHeight = midHeight
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isTextFieldFocused = true
                        }
                    }
                }
            
            if chatViewModel.isInteracting {
                Button {
                    chatViewModel.cancelStreamingResponse()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.red)
                }
            } else {
                Button {
                    Task { @MainActor in
                        isTextFieldFocused = false
                        if let proxy = proxy {
                            scrollToBottom(proxy: proxy)
                        }
                        await chatViewModel.sendTapped()
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                }
                .disabled(chatViewModel.inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Helper Functions
    
    func snapToHeight(height: CGFloat, velocity: CGFloat, minHeight: CGFloat, midHeight: CGFloat, maxHeight: CGFloat) -> CGFloat {
        let clampedHeight = max(minHeight, min(maxHeight, height))
        
        if abs(velocity) > 0.5 {
            if velocity > 0 {
                if clampedHeight < midHeight - 50 {
                    return midHeight
                } else if clampedHeight < maxHeight - 50 {
                    return maxHeight
                } else {
                    return maxHeight
                }
            } else {
                if clampedHeight > midHeight + 50 {
                    return midHeight
                } else if clampedHeight > minHeight + 50 {
                    return minHeight
                } else {
                    return minHeight
                }
            }
        }
        
        let distances = [
            (minHeight, abs(clampedHeight - minHeight)),
            (midHeight, abs(clampedHeight - midHeight)),
            (maxHeight, abs(clampedHeight - maxHeight))
        ]
        
        return distances.min(by: { $0.1 < $1.1 })?.0 ?? midHeight
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let id = chatViewModel.messages.last?.id else { return }
        proxy.scrollTo(id, anchor: .bottomTrailing)
    }
    
    // MARK: - PDF Helper Methods
    
    func loadPDF() {
        // Prefer CommonForms PDF if available
        let effectiveURL = commonFormsPdfURL ?? pdfURL
        
        if let url = effectiveURL {
            currentPDFDocument = PDFDocument(url: url)
            print("📄 Loaded PDF: \(url.lastPathComponent)")
            print("📝 Fields detected: \(commonFormsFields.count)")
        }
    }
}
