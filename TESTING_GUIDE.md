# Testing Guide - Synthetic Widget Mode

## Quick Start Testing

### Prerequisites
1. Xcode 14.0 or later
2. iOS device or simulator (iOS 15.0+)
3. Backend API running and accessible
4. Test PDF files (with and without AcroForm fields)

## Test Scenarios

### Scenario 1: PDF Without AcroForm (Synthetic Mode)

#### Setup
1. Prepare a PDF without native form fields
2. Ensure backend Vision detector is working
3. Upload PDF through the app

#### Expected Behavior
```
1. Upload PDF → Success
2. Backend processes → Returns fieldRegions
3. Navigate to editor → Shows PDF with synthetic widgets
4. Widgets visible → White boxes with borders
5. Tap widget → Keyboard appears
6. Type text → Appears in widget immediately
7. Check form list → Shows same text
8. Edit in form list → PDF updates
9. Submit → Values sent to backend
```

#### Test Steps
```swift
// 1. Upload PDF
HomeView → Tap "Select Document"
         → Choose PDF without forms
         → Tap "Upload & Process"
         → Wait for processing

// 2. Verify widgets created
SplitScreenEditorView → Check PDF pane
                      → Should see white boxes at field locations
                      → Count matches fieldRegions.count

// 3. Test interaction
Tap first widget → Keyboard appears
Type "John Doe" → Text appears in widget
                → Form list updates

// 4. Test sync
Scroll to form list → Find "Name" field
Type "Jane Doe"    → PDF widget updates

// 5. Test submit
Tap "Submit & Generate PDF" → Success alert
                            → Download option available
```

#### Validation
- [ ] Widgets appear at correct positions
- [ ] Widget count matches backend fieldRegions
- [ ] Tapping widget shows keyboard
- [ ] Typing updates widget immediately
- [ ] Form list stays in sync
- [ ] Submit sends correct values

### Scenario 2: PDF With AcroForm (Native Mode)

#### Setup
1. Prepare a PDF with native AcroForm fields
2. Upload through the app

#### Expected Behavior
```
1. Upload PDF → Success
2. Backend detects AcroForm → Returns native fields
3. Navigate to editor → Uses native widgets
4. No synthetic widgets created
5. Native editing works as before
```

#### Test Steps
```swift
// 1. Upload PDF with AcroForm
HomeView → Select PDF with forms
         → Upload & Process

// 2. Verify native mode
SplitScreenEditorView → Check console logs
                      → Should see "PDF has native AcroForm fields"
                      → No synthetic widget creation

// 3. Test native editing
Tap native field → Edit works
Form list sync   → Works as before
```

#### Validation
- [ ] Native AcroForm detected
- [ ] No synthetic widgets created
- [ ] Native editing works
- [ ] Form list syncs correctly

### Scenario 3: Multi-Page PDF

#### Setup
1. Prepare a multi-page PDF without AcroForm
2. Backend should detect fields on multiple pages

#### Expected Behavior
```
1. Upload multi-page PDF → Success
2. Backend returns fieldRegions with different page indices
3. Widgets created on correct pages
4. Scrolling shows widgets on each page
```

#### Test Steps
```swift
// 1. Upload multi-page PDF
HomeView → Select multi-page PDF
         → Upload & Process

// 2. Verify page distribution
Check console logs → Should see widgets on different pages
                   → "Created synthetic widget: field_001 at page 0"
                   → "Created synthetic widget: field_002 at page 1"

// 3. Test scrolling
Scroll PDF → Widgets appear on each page
           → Positioned correctly
```

#### Validation
- [ ] Widgets on correct pages
- [ ] Page indices match backend
- [ ] Scrolling works smoothly
- [ ] All pages editable

### Scenario 4: Edge Cases

#### Test 4.1: Empty Field Regions
```swift
// Backend returns empty fieldRegions array
Expected: Show "No Interactive Fields" message
         Offer QuickLook option
```

#### Test 4.2: Invalid Coordinates
```swift
// Backend returns coordinates outside 0-1 range
Expected: Skip invalid fields
         Log warning
         Continue with valid fields
```

#### Test 4.3: Invalid Page Index
```swift
// Backend returns page index >= pageCount
Expected: Skip field
         Log warning
         Continue with valid fields
```

#### Test 4.4: Large Number of Fields
```swift
// PDF with 100+ fields
Expected: All widgets created
         Performance acceptable (< 1s)
         Scrolling smooth
         Editing responsive
```

## Console Log Verification

### Successful Synthetic Mode
```
✅ Creating synthetic widgets from 15 field regions
📍 Field Regions Count: 15
📍 Region 0: fieldId=name_field, x=0.1, y=0.8, w=0.3, h=0.05, page=0
✨ Created synthetic widget: name_field at page 0, bounds: (61.2, 634.4, 183.6, 39.6)
✨ Created synthetic widget: email_field at page 0, bounds: (61.2, 554.4, 183.6, 39.6)
...
✅ Created 15 synthetic widgets
```

### User Interaction
```
👆 Annotation will hit: name_field
✏️ Field name_field = 'John Doe'
🔄 Synced 1 fields
```

### Errors to Watch For
```
❌ Failed to load PDF
⚠️ Invalid page index 5 for field field_001
⚠️ Invalid coordinates for field field_002
```

## Performance Benchmarks

### Widget Creation
```
Target: < 100ms for 50 fields
Measure: Check console log
         "⏱️ Created 50 widgets in 0.08s"
```

### Sync Operations
```
Target: < 10ms per update
Measure: Type in field, check responsiveness
         Should feel instant
```

### Memory Usage
```
Target: < 10MB for 100 widgets
Measure: Xcode Memory Debugger
         Check for leaks
```

## Automated Testing (Future)

### Unit Tests
```swift
func testCoordinateConversion() {
    let normalized = CGRect(x: 0.5, y: 0.5, width: 0.2, height: 0.1)
    let page = mockPDFPage(size: CGSize(width: 612, height: 792))
    let pdf = normalizedToPDFRect(normalized: normalized, page: page)
    
    XCTAssertEqual(pdf.origin.x, 306, accuracy: 0.1)
    XCTAssertEqual(pdf.origin.y, 396, accuracy: 0.1)
    XCTAssertEqual(pdf.width, 122.4, accuracy: 0.1)
    XCTAssertEqual(pdf.height, 79.2, accuracy: 0.1)
}

func testFieldTypeMapping() {
    let region = FieldRegion(
        fieldId: "test",
        x: 0.1, y: 0.5, width: 0.3, height: 0.05,
        page: 0,
        fieldType: .checkbox,
        source: .ocr
    )
    
    XCTAssertEqual(region.fieldType, .checkbox)
}

func testUUIDMapping() {
    let viewModel = DocumentViewModel(
        components: [component1, component2],
        fieldRegions: [region1, region2],
        documentId: "test",
        selectedFile: nil,
        pdfURL: nil
    )
    
    XCTAssertEqual(viewModel.fieldIdToUUID.count, 2)
    XCTAssertNotNil(viewModel.fieldIdToUUID["field_001"])
}
```

### Integration Tests
```swift
func testSyntheticWidgetCreation() {
    let pdfView = PDFKitRepresentedView(
        pdfURL: testPDFURL,
        formValues: .constant([:]),
        fieldRegions: testRegions,
        fieldIdToUUID: testMapping
    )
    
    let coordinator = pdfView.makeCoordinator()
    coordinator.createSyntheticWidgets()
    
    XCTAssertEqual(coordinator.annotationMap.count, testRegions.count)
}

func testTwoWayBinding() {
    var formValues: [UUID: String] = [testUUID: ""]
    let binding = Binding(get: { formValues }, set: { formValues = $0 })
    
    // Simulate PDF edit
    coordinator.formValues[testUUID] = "New Value"
    
    // Check binding updated
    XCTAssertEqual(formValues[testUUID], "New Value")
}
```

### UI Tests
```swift
func testWidgetInteraction() {
    let app = XCUIApplication()
    app.launch()
    
    // Upload PDF
    app.buttons["Select Document"].tap()
    // ... select test PDF
    
    // Wait for processing
    let editor = app.otherElements["SplitScreenEditorView"]
    XCTAssertTrue(editor.waitForExistence(timeout: 10))
    
    // Tap widget
    let widget = app.otherElements["name_field"]
    widget.tap()
    
    // Type text
    app.keyboards.typeText("John Doe")
    
    // Verify form list
    let formField = app.textFields["Name"]
    XCTAssertEqual(formField.value as? String, "John Doe")
}
```

## Manual Test Checklist

### Basic Functionality
- [ ] App launches without crashes
- [ ] Can select and upload PDF
- [ ] Processing completes successfully
- [ ] Editor view loads
- [ ] Synthetic widgets appear
- [ ] Widgets are at correct positions
- [ ] Can tap and edit widgets
- [ ] Text appears in widgets
- [ ] Form list updates
- [ ] Can edit in form list
- [ ] PDF updates from form list
- [ ] Can submit values
- [ ] Can download filled PDF

### Edge Cases
- [ ] Empty fieldRegions array
- [ ] Invalid coordinates handled
- [ ] Invalid page indices handled
- [ ] Large number of fields (100+)
- [ ] Multi-page PDFs
- [ ] Rotated PDFs
- [ ] Different page sizes
- [ ] Network errors handled
- [ ] Backend timeout handled

### Field Types
- [ ] Text fields work
- [ ] Textarea fields work
- [ ] Date fields work
- [ ] Number fields work
- [ ] Email fields work
- [ ] Phone fields work
- [ ] Checkbox fields work
- [ ] Signature fields work

### Performance
- [ ] Widget creation < 100ms
- [ ] Sync operations < 10ms
- [ ] Scrolling smooth
- [ ] No memory leaks
- [ ] No crashes
- [ ] Battery usage acceptable

### User Experience
- [ ] Widgets look professional
- [ ] Tap targets are adequate
- [ ] Keyboard appears/dismisses correctly
- [ ] Scrolling feels natural
- [ ] Feedback is clear
- [ ] Errors are helpful
- [ ] Loading states shown

## Debugging Tips

### Enable Verbose Logging
```swift
// In PDFKitRepresentedView.Coordinator
print("📍 Creating widget at: x=\(region.x), y=\(region.y)")
print("📍 PDF bounds: \(bounds)")
print("📍 Page size: \(pageRect)")
```

### Check Widget Creation
```swift
// After createSyntheticWidgets()
print("✅ Created \(annotationMap.count) widgets")
for (fieldId, annotation) in annotationMap {
    print("  - \(fieldId): \(annotation.bounds)")
}
```

### Verify Coordinate Mapping
```swift
// Test coordinate conversion
let testNormalized = CGRect(x: 0.5, y: 0.5, width: 0.2, height: 0.1)
let pdfRect = normalizedToPDFRect(normalized: testNormalized, page: page)
print("Normalized: \(testNormalized)")
print("PDF: \(pdfRect)")
```

### Monitor Sync Operations
```swift
// In syncFormValuesToPDF()
var changedCount = 0
for (fieldId, annotation) in annotationMap {
    // ... sync logic
    if newValue != currentValue {
        changedCount += 1
    }
}
if changedCount > 0 {
    print("🔄 Synced \(changedCount) fields")
}
```

## Test Data

### Sample Field Regions
```json
{
  "field_001": {
    "id": "region_001",
    "pageIndex": 0,
    "x": 0.1,
    "y": 0.8,
    "width": 0.3,
    "height": 0.05,
    "fieldType": "text",
    "label": "Full Name",
    "confidence": 0.95
  },
  "field_002": {
    "id": "region_002",
    "pageIndex": 0,
    "x": 0.1,
    "y": 0.7,
    "width": 0.3,
    "height": 0.05,
    "fieldType": "email",
    "label": "Email Address",
    "confidence": 0.92
  }
}
```

### Test PDFs
1. **simple_form.pdf** - Single page, 5 fields
2. **multi_page_form.pdf** - 3 pages, 15 fields
3. **complex_form.pdf** - 5 pages, 50+ fields
4. **acroform.pdf** - Native AcroForm fields
5. **no_fields.pdf** - No detectable fields

## Reporting Issues

When reporting issues, include:
1. iOS version
2. Device model
3. PDF file (if possible)
4. Console logs
5. Steps to reproduce
6. Expected vs actual behavior
7. Screenshots/screen recording

## Success Criteria

✅ All basic functionality tests pass
✅ All edge cases handled gracefully
✅ All field types work correctly
✅ Performance meets benchmarks
✅ User experience is smooth
✅ No crashes or memory leaks
✅ Backend integration works
✅ Documentation is accurate

---

**Happy Testing!** 🎉
