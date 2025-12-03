#!/bin/bash

# DocumentAI Project Setup Script
# Organizes files and prepares for Xcode integration

set -e

echo "🚀 DocumentAI Project Setup"
echo "============================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

echo -e "${BLUE}📁 Project root: $PROJECT_ROOT${NC}"
echo ""

# Check if Xcode project exists
if [ ! -d "documentAI.xcodeproj" ]; then
    echo -e "${RED}❌ Error: documentAI.xcodeproj not found${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Found Xcode project${NC}"
echo ""

# Create organized folder structure
echo -e "${BLUE}📂 Creating organized folder structure...${NC}"

mkdir -p documentAI/App
mkdir -p documentAI/Features/Home
mkdir -p documentAI/Features/DocumentEditor
mkdir -p documentAI/Core/Models
mkdir -p documentAI/Core/Services
mkdir -p documentAI/UI/Components
mkdir -p documentAI/UI/Theme
mkdir -p documentAI/Resources

echo -e "${GREEN}✅ Folder structure created${NC}"
echo ""

# Function to safely move file
move_file() {
    local src="$1"
    local dest="$2"
    
    if [ -f "$src" ]; then
        if [ ! -f "$dest" ]; then
            cp "$src" "$dest"
            echo -e "  ${GREEN}✓${NC} Copied $(basename $src) → $dest"
        else
            echo -e "  ${YELLOW}⊙${NC} $(basename $src) already exists in destination"
        fi
    else
        echo -e "  ${YELLOW}⊙${NC} $(basename $src) not found (may already be moved)"
    fi
}

# Organize files
echo -e "${BLUE}📦 Organizing files...${NC}"

# App
move_file "documentAI/DocumentAIApp.swift" "documentAI/App/DocumentAIApp.swift"

# Features - Home
move_file "documentAI/HomeView.swift" "documentAI/Features/Home/HomeView.swift"
move_file "documentAI/HomeViewModel.swift" "documentAI/Features/Home/HomeViewModel.swift"

# Features - DocumentEditor
move_file "documentAI/SplitScreenEditorView.swift" "documentAI/Features/DocumentEditor/SplitScreenEditorView.swift"
move_file "documentAI/DocumentViewModel.swift" "documentAI/Features/DocumentEditor/DocumentViewModel.swift"
move_file "documentAI/FillDocumentView.swift" "documentAI/Features/DocumentEditor/FillDocumentView.swift"
move_file "documentAI/FillDocumentViewModel.swift" "documentAI/Features/DocumentEditor/FillDocumentViewModel.swift"

# Core - Models
move_file "documentAI/Models.swift" "documentAI/Core/Models/Models.swift"

# Core - Services
move_file "documentAI/APIService.swift" "documentAI/Core/Services/APIService.swift"
move_file "documentAI/LocalFormStorageService.swift" "documentAI/Core/Services/LocalFormStorageService.swift"
move_file "documentAI/LocalStorageService.swift" "documentAI/Core/Services/LocalStorageService.swift"
move_file "documentAI/DocumentPickerService.swift" "documentAI/Core/Services/DocumentPickerService.swift"
move_file "documentAI/ImagePickerService.swift" "documentAI/Core/Services/ImagePickerService.swift"

# UI - Components
move_file "documentAI/PDFKitRepresentedView.swift" "documentAI/UI/Components/PDFKitRepresentedView.swift"
move_file "documentAI/AnimatedGradientBackground.swift" "documentAI/UI/Components/AnimatedGradientBackground.swift"

# UI - Theme
move_file "documentAI/Theme.swift" "documentAI/UI/Theme/Theme.swift"

echo ""
echo -e "${GREEN}✅ Files organized${NC}"
echo ""

# Count Swift files
SWIFT_COUNT=$(find documentAI -name "*.swift" -type f | wc -l | tr -d ' ')
echo -e "${BLUE}📊 Total Swift files: $SWIFT_COUNT${NC}"
echo ""

# Check for new files not in Xcode project
echo -e "${BLUE}🔍 Checking for files not in Xcode project...${NC}"
python3 scripts/update_xcode_project.py

echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo -e "${YELLOW}⚠️  Next Steps:${NC}"
echo "1. Open Xcode: ${BLUE}open documentAI.xcodeproj${NC}"
echo "2. In Xcode Project Navigator:"
echo "   - Delete old file references (select → Delete → Remove Reference)"
echo "   - Right-click documentAI folder → Add Files to 'documentAI'..."
echo "   - Add the organized folders (App/, Features/, Core/, UI/)"
echo "   - Uncheck 'Copy items if needed'"
echo "   - Check 'Create groups' (not folder references)"
echo "   - Check 'Add to targets: documentAI'"
echo "3. Build: ${BLUE}⌘B${NC}"
echo "4. Run: ${BLUE}⌘R${NC}"
echo ""
echo -e "${BLUE}📚 See PROJECT_ORGANIZATION.md for details${NC}"
