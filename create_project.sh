#!/bin/bash

# Create Xcode project structure
PROJECT_NAME="documentAI"
BUNDLE_ID="com.riskcreatives.documentai"
PROJECT_DIR="documentai-swift"

echo "Creating Xcode project for $PROJECT_NAME..."

# Create the Xcode project using xcodebuild
mkdir -p "$PROJECT_DIR/$PROJECT_NAME"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Preview Content"

# Create Info.plist
cat > "$PROJECT_DIR/$PROJECT_NAME/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>We need access to your photo library to select images for processing</string>
    <key>UILaunchScreen</key>
    <dict/>
</dict>
</plist>
EOF

echo "✅ Project structure created"
echo "✅ Info.plist created with photo library permission"
echo "Next: Run xcodebuild to create project file"
