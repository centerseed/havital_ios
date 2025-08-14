#!/bin/bash

# Clean build script for Havital project
echo "🧹 Cleaning Havital project..."

# Clean Xcode build folders
echo "Removing build folders..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Havital-*

# Clean local build folder
if [ -d "build" ]; then
    echo "Removing local build folder..."
    rm -rf build
fi

# Clean SPM cache (optional - uncomment if needed)
# echo "Cleaning Swift Package Manager cache..."
# rm -rf ~/Library/Caches/org.swift.swiftpm

echo "✅ Clean complete!"
echo ""
echo "🔨 To rebuild the project, run:"
echo "xcodebuild -project Havital.xcodeproj -scheme \"Havital Dev\" -destination 'platform=iOS Simulator,name=iPhone 16' build"