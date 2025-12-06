#!/usr/bin/env python3
"""
Automatically add new Swift files to Xcode project
Uses pbxproj library for safe manipulation
"""

import os
import sys
from pathlib import Path

try:
    from pbxproj import XcodeProject
except ImportError:
    print("❌ pbxproj library not found. Installing...")
    os.system("pip3 install pbxproj --user --quiet")
    from pbxproj import XcodeProject

def find_swift_files(root_dir):
    """Find all Swift files in the project"""
    swift_files = []
    for root, dirs, files in os.walk(root_dir):
        # Skip build directories and hidden folders
        dirs[:] = [d for d in dirs if not d.startswith('.') and d not in ['build', 'DerivedData']]
        
        for file in files:
            if file.endswith('.swift'):
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, '.')
                swift_files.append(rel_path)
    
    return swift_files

def get_files_in_project(project):
    """Get list of files already in the Xcode project"""
    existing_files = set()
    
    for obj in project.objects.get_objects_in_section('PBXFileReference'):
        if hasattr(obj, 'path') and obj.path:
            existing_files.add(obj.path)
    
    return existing_files

def add_files_to_project(project_path, files_to_add):
    """Add files to Xcode project"""
    
    if not files_to_add:
        print("✅ No new files to add")
        return True
    
    print(f"\n📝 Adding {len(files_to_add)} files to Xcode project...")
    
    try:
        # Load project
        project = XcodeProject.load(project_path)
        
        # Get the main target
        target = project.get_target_by_name('documentAI')
        if not target:
            print("❌ Could not find 'documentAI' target")
            return False
        
        # Add each file
        for file_path in files_to_add:
            try:
                # Determine the group path
                dir_path = os.path.dirname(file_path)
                
                # Add file to project
                project.add_file(file_path, parent=project, target_name='documentAI')
                print(f"  ✅ Added: {file_path}")
                
            except Exception as e:
                print(f"  ⚠️  Could not add {file_path}: {e}")
        
        # Save project
        project.save()
        print("\n✅ Project file updated successfully!")
        return True
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def main():
    project_path = 'documentAI.xcodeproj/project.pbxproj'
    
    if not os.path.exists(project_path):
        print(f"❌ Project file not found: {project_path}")
        sys.exit(1)
    
    # Create backup
    backup_path = project_path + '.backup'
    if not os.path.exists(backup_path):
        import shutil
        shutil.copy2(project_path, backup_path)
        print(f"💾 Created backup: {backup_path}")
    
    print("🔍 Scanning for Swift files...")
    
    # Find all Swift files in the project
    all_swift_files = find_swift_files('documentAI')
    print(f"📁 Found {len(all_swift_files)} Swift files in filesystem")
    
    # Load project and get existing files
    try:
        project = XcodeProject.load(project_path)
        existing_files = get_files_in_project(project)
        print(f"📋 Found {len(existing_files)} files in Xcode project")
    except Exception as e:
        print(f"❌ Could not load project: {e}")
        sys.exit(1)
    
    # Find files that need to be added
    files_to_add = []
    for swift_file in all_swift_files:
        # Check if file is already in project
        file_name = os.path.basename(swift_file)
        if file_name not in existing_files and swift_file not in existing_files:
            files_to_add.append(swift_file)
    
    if not files_to_add:
        print("\n✅ All files are already in the Xcode project!")
        return
    
    print(f"\n📝 Found {len(files_to_add)} new files to add:")
    for f in files_to_add:
        print(f"  - {f}")
    
    # Add files
    if add_files_to_project(project_path, files_to_add):
        print("\n🎉 Done! You can now build the project.")
    else:
        print("\n❌ Failed to add files. Check the errors above.")
        sys.exit(1)

if __name__ == '__main__':
    main()
