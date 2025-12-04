#!/bin/bash

# Script to remove deleted files from Xcode project

PROJECT_FILE="documentAI.xcodeproj/project.pbxproj"

echo "Fixing Xcode project references..."

# Backup the project file
cp "$PROJECT_FILE" "$PROJECT_FILE.backup"

# Remove references to deleted files
sed -i '' '/FillDocumentViewModel\.swift/d' "$PROJECT_FILE"
sed -i '' '/FillDocumentView\.swift/d' "$PROJECT_FILE"

echo "✅ Fixed! Backup saved as $PROJECT_FILE.backup"
echo "Now try building in Xcode (Cmd+B)"
