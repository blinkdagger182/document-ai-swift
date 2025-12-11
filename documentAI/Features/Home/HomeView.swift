//
//  HomeView.swift
//  documentAI
//
//  Main home screen for document upload
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var chatMessage = ""
    
    var body: some View {
        ZStack {
            AnimatedGradientBackground()
                .ignoresSafeArea()
            
            if viewModel.showResults {
                DocumentChatView(
                    documentId: viewModel.documentId,
                    selectedFile: viewModel.selectedFile,
                    pdfURL: viewModel.pdfURL,
                    commonFormsPdfURL: viewModel.commonFormsPdfURL,
                    commonFormsFields: viewModel.commonFormsFields,
                    onBack: {
                        viewModel.showResults = false
                    }
                )
            } else {
                homeContent
            }
        }
        .alert(item: $viewModel.alertState) { alertState in
            Alert(
                title: Text(alertState.title),
                message: Text(alertState.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private var homeContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    greetingHeader
                    documentActionsSection
                    recentDocumentsSection
                    aiPromptSuggestions
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
            
            Spacer()
            
            chatInputSection
        }
    }
    
    // MARK: - Greeting Header
    private var greetingHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Good evening, Azhan")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.black.opacity(0.7))
                
                Text("Your documents")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.black)
            }
            
            Spacer()
            
            Circle()
                .fill(Color.purple)
                .frame(width: 44, height: 44)
                .overlay(
                    Text("A")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                )
        }
        .padding(.top, 8)
    }
    
    // MARK: - Document Actions Section
    private var documentActionsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                actionButton(icon: "plus", text: "Scan PDF") {
                    Task {
                        await viewModel.pickImage()
                    }
                }
                
                actionButton(icon: "folder", text: "Upload from Files") {
                    Task {
                        await viewModel.pickDocument()
                    }
                }
            }
            
            // Show selected file
            if let file = viewModel.selectedFile {
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundColor(.purple)
                    Text(file.name)
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        viewModel.reset()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
            }
            
            // Upload button
            if viewModel.selectedFile != nil {
                uploadButton
            }
        }
    }
    
    private func actionButton(icon: String, text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                Text(text)
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.black)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        }
    }
    
    // MARK: - Upload Button
    private var uploadButton: some View {
        Button {
            Task {
                await viewModel.uploadAndProcess()
            }
        } label: {
            HStack {
                if viewModel.uploading || viewModel.processing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text(viewModel.uploading ? "Uploading..." : "Processing...")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                    Text("Upload & Process")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.purple)
            .cornerRadius(12)
            .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(viewModel.selectedFile == nil || viewModel.uploading || viewModel.processing)
        .opacity(viewModel.selectedFile == nil ? 0.6 : 1.0)
    }
    
    // MARK: - Recent Documents Section
    private var recentDocumentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent documents")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.black)
            
            VStack(spacing: 12) {
                documentRow(
                    title: "W-4 Form",
                    time: "5 minutes ago",
                    pages: "1 pages",
                    tag: "Forms",
                    hasCheckmark: true
                )
                
                documentRow(
                    title: "Rent Invoice – January",
                    time: "1 hour ago",
                    pages: "1 pages",
                    tag: "Invoice",
                    hasCheckmark: false
                )
                
                documentRow(
                    title: "NDA – Project X",
                    time: "3 hours ago",
                    pages: "3 pages",
                    tag: "Contract",
                    hasCheckmark: false
                )
                
                documentRow(
                    title: "Employment Contract – ACME",
                    time: "1 day ago",
                    pages: "12 pages",
                    tag: "AI",
                    hasCheckmark: true
                )
            }
        }
    }
    
    private func documentRow(title: String, time: String, pages: String, tag: String, hasCheckmark: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.red)
                
                if hasCheckmark {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 4, y: 4)
                }
            }
            .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                
                Text("\(time) · \(pages)")
                    .font(.system(size: 14))
                    .foregroundColor(.black.opacity(0.5))
            }
            
            Spacer()
            
            Text(tag)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.black.opacity(0.7))
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - AI Prompt Suggestions
    private var aiPromptSuggestions: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                promptChip(text: "Summarize all unread")
                promptChip(text: "Find documents")
            }
            
            HStack(spacing: 12) {
                promptChip(text: "due this week")
                promptChip(text: "Show forms I need to sign")
            }
        }
        .padding(.top, 8)
    }
    
    private func promptChip(text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.black.opacity(0.8))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
            )
    }
    
    // MARK: - Chat Input Section
    private var chatInputSection: some View {
        HStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 20))
                .foregroundColor(.purple)
            
            TextField("Ask documentAI anything", text: $chatMessage)
                .font(.system(size: 16))
                .foregroundColor(.black)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: -4)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}

#Preview {
    HomeView()
}
