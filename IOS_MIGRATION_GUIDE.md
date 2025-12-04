# iOS App Migration Guide

This guide explains the changes made to conform to the architecture specification.

## What Changed?

### Before (Old Architecture)
- Called `document-ai-gcp` standalone service
- Used `/ui/generate` and `/overlay` endpoints
- Stateless flow (no database tracking)
- No polling mechanism
- Direct PDF overlay in single request

### After (New Architecture - Spec Compliant)
- Calls `document-ai-fastapi` main backend
- Uses 6 REST endpoints: `/api/v1/documents/*`
- Database-backed flow with document tracking
- Polling for async processing
- Proper separation: upload → process → fill → compose → download

## Updated Files

### 1. APIService.swift (Complete Rewrite)

**Old endpoints:**
```swift
POST /ui/generate  // OCR processing
POST /overlay      // PDF filling
```

**New endpoints (spec-compliant):**
```swift
POST /api/v1/documents/init-upload     // Upload file
POST /api/v1/documents/{id}/process    // Start OCR
GET  /api/v1/documents/{id}            // Get status/fields
POST /api/v1/documents/{id}/values     // Submit values
POST /api/v1/documents/{id}/compose    // Generate PDF
GET  /api/v1/documents/{id}/download   // Get download URL
```

**Key changes:**
- Added `initUpload()` method
- Added `processDocument()` method
- Added `getDocument()` method
- Added `submitValues()` method
- Added `composePDF()` method
- Added `downloadPDF()` method
- Added `pollUntilReady()` helper
- Added `pollUntilFilled()` helper
- Removed `uploadAndProcessDocument()` (old method)
- Removed `overlayPDF()` (old method)

### 2. HomeViewModel.swift

**Old flow:**
```swift
func uploadAndProcess() {
    let result = try await apiService.uploadAndProcessDocument(file: file)
    // Got components immediately
}
```

**New flow (spec-compliant):**
```swift
func uploadAndProcess() {
    // Step 1: Upload
    let uploadResponse = try await apiService.initUpload(file: file)
    documentId = uploadResponse.documentId
    
    // Step 2: Start processing
    try await apiService.processDocument(documentId: documentId)
    
    // Step 3: Poll until ready
    let detail = try await apiService.pollUntilReady(documentId: documentId)
    
    // Step 4: Extract components
    components = detail.components
    fieldRegions = detail.fieldMap
}
```

**Key changes:**
- Multi-step async flow instead of single request
- Polling mechanism for OCR completion
- Document ID tracking throughout lifecycle
- Proper status handling (imported → processing → ready)

### 3. DocumentViewModel.swift

**Old flow:**
```swift
func submitAndGeneratePDF() {
    let result = try await apiService.overlayPDF(
        document: file,
        documentId: documentId,
        formData: formData,
        fieldRegions: fieldRegions
    )
    // Got PDF immediately
}
```

**New flow (spec-compliant):**
```swift
func submitAndGeneratePDF() {
    // Step 1: Submit values to database
    try await apiService.submitValues(documentId: documentId, values: valueInputs)
    
    // Step 2: Start PDF composition
    try await apiService.composePDF(documentId: documentId)
    
    // Step 3: Poll until filled
    try await apiService.pollUntilFilled(documentId: documentId)
    
    // Step 4: Get download URL
    let downloadResponse = try await apiService.downloadPDF(documentId: documentId)
    
    // Step 5: Download and share
    await downloadFilledPDF(url: downloadResponse.filledPdfUrl)
}
```

**Key changes:**
- Values submitted to database (not sent with PDF)
- Separate compose step (async worker)
- Polling for composition completion
- Presigned URL for download
- Added `downloadFilledPDF()` helper method

### 4. Models.swift

**Added fields to FieldComponent:**
```swift
struct FieldComponent {
    let id: String
    let fieldId: String?        // NEW: Backend field region ID
    let type: FieldType
    let label: String
    let placeholder: String?
    let options: [String]?
    let value: AnyCodable?
    let pageIndex: Int?         // NEW: Page number
    let defaultValue: String?   // NEW: Default value
}
```

**Why?** Backend returns `fieldId` (UUID from field_regions table) which is used for value submission.

## Configuration Required

### Update API Base URL

Edit `documentai-swift/documentAI/Core/Services/APIService.swift`:

```swift
// Line 12: Replace with your deployed FastAPI URL
private let baseURL = "https://your-fastapi-backend.run.app"
```

**How to get this URL:**
1. Deploy document-ai-fastapi to Cloud Run (see DEPLOYMENT_GUIDE.md)
2. Copy the service URL from deployment output
3. Paste it here (without trailing slash)

Example:
```swift
private let baseURL = "https://documentai-api-824241800977.us-central1.run.app"
```

## Testing the New Flow

### 1. Test Upload & Process

```swift
// In HomeView, tap "Upload & Process"
// Expected console output:
✅ Document uploaded: abc-123-def
⏳ Polling attempt 1/60: status=processing
⏳ Polling attempt 2/60: status=processing
✅ Document ready: 15 fields, AcroForm: true
```

### 2. Test Fill & Submit

```swift
// Fill form fields, tap "Submit & Generate PDF"
// Expected console output:
✅ Values submitted: 15 fields
⏳ Waiting for PDF composition...
⏳ Polling composition 1/60: status=filling
⏳ Polling composition 2/60: status=filling
✅ PDF ready: https://storage.googleapis.com/...
```

### 3. Test Download

```swift
// Tap "Download" in success alert
// Expected: iOS share sheet appears with filled PDF
```

## Troubleshooting

### Issue: "Invalid server response"

**Cause:** API base URL not set or incorrect

**Solution:**
1. Check `APIService.swift` line 12
2. Verify URL is correct (no trailing slash)
3. Test URL in browser: `https://your-url/api/v1/health`

### Issue: "Request timed out"

**Cause:** Polling exceeded max attempts (60 × 2s = 2 minutes)

**Solution:**
1. Check backend logs for errors
2. Verify OCR worker is deployed and running
3. Increase timeout in `pollUntilReady()`:
```swift
func pollUntilReady(documentId: String, maxAttempts: Int = 120) // 4 minutes
```

### Issue: "Failed to fetch document details"

**Cause:** Document ID not found in database

**Solution:**
1. Verify `initUpload()` returned valid documentId
2. Check database for document record
3. Verify backend is connected to correct database

### Issue: "Processing failed: Unknown error"

**Cause:** OCR worker encountered an error

**Solution:**
1. Check OCR worker logs in Cloud Run
2. Verify worker has access to storage
3. Check if PDF is valid/not corrupted

### Issue: "Failed to get download URL"

**Cause:** PDF composition not complete or failed

**Solution:**
1. Check composer worker logs
2. Verify document status is "filled"
3. Check if storage_key_filled is set in database

## Debugging Tips

### Enable Verbose Logging

Add to `APIService.swift` methods:
```swift
print("📤 Request: \(request.url?.absoluteString ?? "")")
print("📥 Response: \(String(data: data, encoding: .utf8) ?? "")")
```

### Check Document Status

Add to `HomeViewModel.swift`:
```swift
let detail = try await apiService.getDocument(documentId: documentId)
print("📊 Status: \(detail.document.status)")
print("📊 Fields: \(detail.components.count)")
print("📊 AcroForm: \(detail.document.acroform ?? false)")
```

### Monitor Network Requests

In Xcode:
1. Run app
2. Open Debug Navigator (⌘7)
3. Select "Network" to see all HTTP requests

## Migration Checklist

- [ ] Updated `APIService.swift` with new base URL
- [ ] Tested upload flow (init-upload → process → poll)
- [ ] Tested form filling
- [ ] Tested submission flow (values → compose → poll → download)
- [ ] Verified PDF download works
- [ ] Tested error handling (invalid file, timeout, etc.)
- [ ] Verified autosave still works
- [ ] Tested split-screen editor
- [ ] Tested PDF annotation updates
- [ ] Verified two-way binding works

## Benefits of New Architecture

✅ **Database persistence** - Documents tracked throughout lifecycle
✅ **Async processing** - No timeout on large PDFs
✅ **Scalability** - Workers can scale independently
✅ **Reliability** - Retry failed tasks via Cloud Tasks
✅ **Monitoring** - Track document status in database
✅ **AcroForm support** - Native PDF form detection
✅ **Cost efficiency** - Workers only run when needed
✅ **Separation of concerns** - API, OCR, and composition are separate services

## Next Steps

1. Deploy backend (see `../DEPLOYMENT_GUIDE.md`)
2. Update API base URL in `APIService.swift`
3. Build and test iOS app
4. Monitor logs for any issues
5. Implement authentication (optional)
6. Submit to App Store

---

For architecture details, see `../ARCHITECTURE_CONFORMANCE.md`
