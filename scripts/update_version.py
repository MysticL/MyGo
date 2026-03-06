#!/usr/bin/env python3
import argparse
import datetime
import os
import re
import sys

PROJECT_FILE = 'MyGo.xcodeproj/project.pbxproj'
CHANGELOG_FILE = 'CHANGELOG.md'

def get_current_versions():
    if not os.path.exists(PROJECT_FILE):
        print(f"Error: Project file not found at {PROJECT_FILE}")
        sys.exit(1)
        
    with open(PROJECT_FILE, 'r') as f:
        content = f.read()
        
    marketing_match = re.search(r'MARKETING_VERSION = ([\d\.]+);', content)
    build_match = re.search(r'CURRENT_PROJECT_VERSION = ([\d]+);', content)
    
    if not marketing_match or not build_match:
        print("Error: Could not find version settings in project.pbxproj")
        sys.exit(1)
        
    return marketing_match.group(1), build_match.group(1)

def increment_marketing_version(version, type_):
    parts = list(map(int, version.split('.')))
    while len(parts) < 3:
        parts.append(0)
    
    if type_ == 'major':
        parts[0] += 1
        parts[1] = 0
        parts[2] = 0
    elif type_ == 'minor':
        parts[1] += 1
        parts[2] = 0
    else:
        parts[2] += 1
        
    return f"{parts[0]}.{parts[1]}.{parts[2]}"

def update_project_file(new_marketing, new_build):
    with open(PROJECT_FILE, 'r') as f:
        content = f.read()
        
    # Replace all occurrences
    content = re.sub(r'MARKETING_VERSION = [\d\.]+;', f'MARKETING_VERSION = {new_marketing};', content)
    content = re.sub(r'CURRENT_PROJECT_VERSION = [\d]+;', f'CURRENT_PROJECT_VERSION = {new_build};', content)
    
    with open(PROJECT_FILE, 'w') as f:
        f.write(content)

def update_changelog(new_version, description):
    today = datetime.date.today().strftime('%Y-%m-%d')
    new_entry = f"\n## [{new_version}] - {today}\n### Changed\n- {description}\n"
    
    if not os.path.exists(CHANGELOG_FILE):
        with open(CHANGELOG_FILE, 'w') as f:
            f.write("# Changelog\n\nAll notable changes to this project will be documented in this file.\n")
    
    with open(CHANGELOG_FILE, 'r') as f:
        content = f.read()
    
    match = re.search(r'^## \[', content, re.MULTILINE)
    
    if match:
        insertion_index = match.start()
        new_content = content[:insertion_index] + new_entry + content[insertion_index:]
    else:
        header_match = re.search(r'# Changelog.*?\n\n', content, re.DOTALL)
        if header_match:
             new_content = content.rstrip() + "\n" + new_entry
        else:
            new_content = "# Changelog\n\n" + new_entry + content
            
    with open(CHANGELOG_FILE, 'w') as f:
        f.write(new_content)

def main():
    parser = argparse.ArgumentParser(description='Update version and changelog.')
    parser.add_argument('description', help='Description of the changes')
    parser.add_argument('--type', choices=['major', 'minor', 'patch'], default='patch', help='Type of version bump')
    args = parser.parse_args()

    # 1. Get current version
    current_marketing, current_build = get_current_versions()
    print(f"Current Marketing Version: {current_marketing}")
    print(f"Current Build Version: {current_build}")
    
    # 2. Calculate new version
    new_marketing = increment_marketing_version(current_marketing, args.type)
    
    # Build version: simple increment
    try:
        new_build = str(int(current_build) + 1)
    except ValueError:
        # Fallback if build version is not integer (unlikely based on my check)
        new_build = current_build + ".1"

    print(f"New Marketing Version: {new_marketing}")
    print(f"New Build Version: {new_build}")
    
    # 3. Update Xcode project
    print("Updating Xcode project...")
    update_project_file(new_marketing, new_build)
    
    # 4. Update Changelog
    print("Updating CHANGELOG.md...")
    update_changelog(new_marketing, args.description)
    
    print("Done!")

if __name__ == "__main__":
    main()
