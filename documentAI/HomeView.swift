//
//  HomeView.swift
//  documentAI
//
//  Main home screen for document upload
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    
    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            
            if viewModel.showResults {
                FillDocumentView(
                    components: viewModel.components,
                    fieldMap: viewModel.fieldMap,
                    formData: viewModel.formData,
                    documentId: viewModel.documentId,
                    selectedFile: viewModel.selectedFile,
                    onBack: {
                        viewModel.showResults = false
                    },
                    onUploadAnother: {
                        viewModel.reset()
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
        ScrollView {
            VStack(spacing: Theme.Spacing.xxl) {
                headerSection
                uploadBoxSection
                
                if viewModel.selectedFile != nil {
                    uploadButtonSection
                    
                    if viewModel.uploading {
                        progressBarSection
                    }
                }
                
                featuresSection
            }
            .padding(Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.xxxl)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "doc.text.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(Theme.Colors.primary)
            
            Text("documentAI")
                .font(Theme.Typography.largeTitle)
                .foregroundColor(Theme.Colors.textPrimary)
            
            Text("Upload & Process Documents with AI")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Upload Box Section
    private var uploadBoxSection: some View {
        VStack(spacing: Theme.Spacing.xl) {
            if let file = viewModel.selectedFile {
                fileInfoView(file: file)
            } else {
                emptyUploadView
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.xxxl)
        .background(Theme.Colors.cardBackground.opacity(0.95))
        .cornerRadius(Theme.CornerRadius.xxl)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.xxl)
                .stroke(
                    style: StrokeStyle(
                        lineWidth: 2,
                        dash: [10, 5]
                    )
                )
                .foregroundColor(Theme.Colors.primary)
        )
        .shadow(
            color: Theme.Shadows.card.color,
            radius: Theme.Shadows.card.radius,
            x: Theme.Shadows.card.x,
            y: Theme.Shadows.card.y
        )
    }
    
    // MARK: - Empty Upload View
    private var emptyUploadView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Image(systemName: "icloud.and.arrow.up")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(Theme.Colors.primary)
            
            Text("Upload Your Document")
                .font(Theme.Typography.title)
                .foregroundColor(Theme.Colors.textPrimary)
            
            Text("PDF, Images, or Scanned Documents")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
            
            HStack(spacing: Theme.Spacing.md) {
                Button {
                    Task {
                        await viewModel.pickDocument()
                    }
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "doc")
                        Text("Document")
                    }
                    .font(Theme.Typography.bodySemibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.Colors.primary)
                    .cornerRadius(Theme.CornerRadius.md)
                }
                
                Button {
                    Task {
                        await viewModel.pickImage()
                    }
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "photo")
                        Text("Image")
                    }
                    .font(Theme.Typography.bodySemibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.Colors.secondary)
                    .cornerRadius(Theme.CornerRadius.md)
                }
            }
        }
    }
    
    // MARK: - File Info View
    private func fileInfoView(file: DocumentModel) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: file.isPDF ? "doc.fill" : "photo.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundColor(Theme.Colors.primary)
            
            Text(file.name)
                .font(Theme.Typography.bodySemibold)
                .foregroundColor(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, Theme.Spacing.xl)
            
            Text("\(file.sizeInKB) KB")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
            
            Button {
                Task {
                    await viewModel.pickDocument()
                }
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "arrow.left.arrow.right")
                    Text("Change")
                }
                .font(Theme.Typography.captionMedium)
                .foregroundColor(Theme.Colors.textSecondary)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                        .stroke(Theme.Colors.border, lineWidth: 1)
                )
            }
            .disabled(viewModel.uploading || viewModel.processing)
        }
    }
    
    // MARK: - Upload Button Section
    private var uploadButtonSection: some View {
        Button {
            Task {
                await viewModel.uploadAndProcess()
            }
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                if viewModel.uploading || viewModel.processing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text(viewModel.uploading ? "Uploading \(Int(viewModel.progress))%" : "Processing...")
                        .font(Theme.Typography.bodySemibold)
                } else {
                    Image(systemName: "icloud.and.arrow.up")
                    Text("Upload & Process")
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
            .opacity((viewModel.uploading || viewModel.processing) ? 0.6 : 1.0)
        }
        .disabled(viewModel.uploading || viewModel.processing)
    }
    
    // MARK: - Progress Bar Section
    private var progressBarSection: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Theme.Colors.progressTrack)
                    .frame(height: 8)
                    .cornerRadius(4)
                
                Rectangle()
                    .fill(Theme.Colors.primary)
                    .frame(width: geometry.size.width * (viewModel.progress / 100), height: 8)
                    .cornerRadius(4)
            }
        }
        .frame(height: 8)
    }
    
    // MARK: - Features Section
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("Features")
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.textPrimary)
            
            featureRow(icon: "scanner", text: "Multi-page scanning")
            featureRow(icon: "chart.bar", text: "AI-powered extraction")
            featureRow(icon: "pencil", text: "Editable forms")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.xl)
        .background(Theme.Colors.cardBackground.opacity(0.9))
        .cornerRadius(Theme.CornerRadius.lg)
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundColor(Theme.Colors.primary)
            
            Text(text)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textSecondary)
        }
    }
}

#Preview {
    HomeView()
}
